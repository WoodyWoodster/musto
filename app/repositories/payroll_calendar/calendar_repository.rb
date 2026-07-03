module PayrollCalendar
  class CalendarRepository < ApplicationRepository
    def initialize(employer: nil)
      @employer = employer
    end

    def schedules
      return PayrollSchedule.none unless @employer

      @employer.payroll_schedules.upcoming_first
    end

    def current_schedule
      schedules.active.first || schedules.first
    end

    def current_run
      return unless @employer

      @employer
        .payroll_runs
        .includes(:payroll_deductions, :payroll_adjustments, :pay_statements, :payroll_approval_steps, employer: [ :employees, :employer_bank_accounts ])
        .order(pay_date: :desc)
        .first
    end

    def approval_steps
      run = current_run
      return PayrollApprovalStep.none unless run

      run.payroll_approval_steps.includes(:payroll_schedule).ordered
    end

    def checklists
      payload = @employer&.settings.to_h.fetch("payroll_calendar_checklist", nil)
      payload.present? ? [ payload ] : []
    end

    def find_step(id)
      PayrollApprovalStep.includes(:payroll_run, :payroll_schedule).find(id)
    end

    def complete_step(step, completed_by:)
      step.complete!(completed_by:)
      step
    end

    def generate_checklist(requested_by:)
      schedule = current_schedule || create_schedule
      run = current_run || create_run(schedule)
      steps = checklist_templates(run, schedule).map do |attributes|
        step = run.payroll_approval_steps.find_or_initialize_by(key: attributes.fetch(:key))
        step.payroll_schedule ||= schedule

        unless step.completed?
          step.assign_attributes(attributes.except(:key))
          step.save!
        end

        step
      end

      batch = checklist_payload(run, schedule, steps, requested_by:)
      @employer.update!(settings: @employer.settings.to_h.merge("payroll_calendar_checklist" => batch))
      batch
    end

    def submitted_time_entries_for(run)
      time_entries_for(run).pending_review
    end

    def waiting_deductions_for(run)
      return PayrollDeduction.none unless run

      run.payroll_deductions.where.not(status: "ready")
    end

    def pending_employee_accounts
      return EmployeeBankAccount.none unless @employer

      EmployeeBankAccount.joins(:employee).where(employees: { employer_id: @employer.id }).pending_review
    end

    def blocked_employee_accounts
      return EmployeeBankAccount.none unless @employer

      EmployeeBankAccount.joins(:employee).where(employees: { employer_id: @employer.id }, status: "blocked")
    end

    def employer_funding_ready?
      @employer&.employer_bank_accounts&.verified&.exists? || false
    end

    private

    def create_schedule
      run = current_run
      cadence = normalize_cadence(@employer.settings.to_h.fetch("pay_frequency", "biweekly"))
      period_start_on = run&.period_start_on || Date.current.beginning_of_month
      period_end_on = run&.period_end_on || Date.current.end_of_month
      pay_date = run&.pay_date || period_end_on
      zone = @employer.settings.to_h.fetch("timezone", "America/Los_Angeles")

      @employer.payroll_schedules.create!(
        name: "Primary payroll schedule",
        cadence:,
        period_anchor_on: period_start_on,
        next_period_start_on: period_start_on,
        next_period_end_on: period_end_on,
        next_pay_date: pay_date,
        approval_deadline_at: deadline_at(pay_date, zone:, days_before: 2, hour: 12),
        funding_deadline_at: deadline_at(pay_date, zone:, days_before: 1, hour: 14),
        timezone: zone,
        metadata: { "source" => "generated_payroll_calendar" }
      )
    end

    def create_run(schedule)
      gross_pay_cents = @employer.employees.active.sum(:compensation_cents) / periods_per_year(schedule.cadence)

      @employer.payroll_runs.create!(
        period_start_on: schedule.next_period_start_on,
        period_end_on: schedule.next_period_end_on,
        pay_date: schedule.next_pay_date,
        gross_pay_cents:,
        status: "estimated",
        metadata: { "source" => "generated_payroll_calendar" }
      )
    end

    def checklist_templates(run, schedule)
      time_entries = time_entries_for(run).to_a
      submitted_entries = time_entries.select(&:submitted?)
      waiting_deductions = waiting_deductions_for(run).to_a
      pending_accounts = pending_employee_accounts.to_a
      blocked_accounts = blocked_employee_accounts.to_a
      funding_ready = employer_funding_ready?
      statements = run.pay_statements.to_a
      hard_blockers = submitted_entries.count + waiting_deductions.count + pending_accounts.count + blocked_accounts.count + (funding_ready ? 0 : 1)

      [
        step_attributes(
          key: "time_review",
          title: "Approve time and attendance",
          owner: "Managers",
          due_at: schedule.approval_deadline_at - 8.hours,
          status: submitted_entries.any? ? "blocked" : "open",
          severity: submitted_entries.any? ? "high" : "medium",
          position: 1,
          detail: submitted_entries.any? ? "#{submitted_entries.count} submitted time entries need approval before payroll can close." : "#{time_entries.count(&:approved?)} approved time entries are ready for payroll.",
          count: submitted_entries.count
        ),
        step_attributes(
          key: "adjustment_review",
          title: "Certify payroll adjustments",
          owner: "Payroll",
          due_at: schedule.approval_deadline_at - 4.hours,
          status: "open",
          severity: "medium",
          position: 2,
          detail: "#{run.payroll_adjustments.count} bonuses, reimbursements, or corrections are staged for this run.",
          count: run.payroll_adjustments.count,
          amount_cents: run.total_adjustments_cents
        ),
        step_attributes(
          key: "benefit_deductions",
          title: "Clear Vitable benefit deductions",
          owner: "Benefits",
          due_at: schedule.approval_deadline_at,
          status: waiting_deductions.any? ? "blocked" : "open",
          severity: waiting_deductions.any? ? "high" : "medium",
          position: 3,
          detail: waiting_deductions.any? ? "#{waiting_deductions.count} deductions are still waiting on enrollment or Vitable sync." : "#{run.payroll_deductions.count} benefit deductions are ready for payroll.",
          count: waiting_deductions.count,
          amount_cents: run.total_deductions_cents
        ),
        step_attributes(
          key: "funding_source",
          title: "Confirm employer funding source",
          owner: "Finance",
          due_at: schedule.funding_deadline_at - 4.hours,
          status: funding_ready ? "open" : "blocked",
          severity: funding_ready ? "medium" : "critical",
          position: 4,
          detail: funding_ready ? "Verified company funding is available for ACH debit." : "No verified company funding account is available for payroll ACH debit.",
          count: funding_ready ? 0 : 1,
          amount_cents: run.estimated_net_pay_cents
        ),
        step_attributes(
          key: "employee_deposits",
          title: "Confirm employee direct deposit",
          owner: "People Ops",
          due_at: schedule.funding_deadline_at - 2.hours,
          status: pending_accounts.any? || blocked_accounts.any? ? "blocked" : "open",
          severity: blocked_accounts.any? ? "high" : "medium",
          position: 5,
          detail: "#{pending_accounts.count} pending and #{blocked_accounts.count} blocked employee bank accounts need review.",
          count: pending_accounts.count + blocked_accounts.count
        ),
        step_attributes(
          key: "statement_preview",
          title: "Preview employee pay statements",
          owner: "Payroll",
          due_at: schedule.funding_deadline_at,
          status: statements.any? ? "open" : "in_progress",
          severity: "low",
          position: 6,
          detail: statements.any? ? "#{statements.count} pay statements are generated for employee preview." : "Generate pay statements before locking the run.",
          count: statements.count,
          amount_cents: run.estimated_net_pay_cents
        ),
        step_attributes(
          key: "final_approval",
          title: "Final payroll approval",
          owner: "Payroll admin",
          due_at: schedule.funding_deadline_at + 2.hours,
          status: hard_blockers.positive? ? "blocked" : "open",
          severity: hard_blockers.positive? ? "high" : "medium",
          position: 7,
          detail: hard_blockers.positive? ? "#{hard_blockers} blocker records remain before final approval." : "All upstream payroll controls are ready for final approval.",
          count: hard_blockers,
          amount_cents: run.estimated_net_pay_cents
        )
      ]
    end

    def step_attributes(key:, title:, owner:, due_at:, status:, severity:, position:, detail:, count:, amount_cents: 0)
      {
        key:,
        title:,
        owner:,
        due_at:,
        status:,
        severity:,
        position:,
        metadata: {
          "detail" => detail,
          "count" => count,
          "amount_cents" => amount_cents
        }
      }
    end

    def checklist_payload(run, schedule, steps, requested_by:)
      {
        "batch_id" => "payroll_calendar_#{@employer.id}_#{run.id}_#{Time.current.to_i}",
        "generated_at" => Time.current.iso8601,
        "requested_by" => requested_by,
        "employer_id" => @employer.id,
        "payroll_run_id" => run.id,
        "payroll_schedule_id" => schedule.id,
        "status" => steps.any?(&:blocked?) ? "needs_review" : "ready",
        "totals" => {
          "step_count" => steps.count,
          "blocked_count" => steps.count(&:blocked?),
          "completed_count" => steps.count(&:completed?)
        },
        "lines" => steps.map { |step| checklist_line(step) }
      }
    end

    def checklist_line(step)
      {
        "approval_step_id" => step.id,
        "key" => step.key,
        "title" => step.title,
        "owner" => step.owner,
        "status" => step.status,
        "severity" => step.severity,
        "due_at" => step.due_at.iso8601,
        "detail" => step.metadata.to_h.fetch("detail", "Review and certify this payroll control."),
        "count" => step.metadata.to_h.fetch("count", 0),
        "amount_cents" => step.metadata.to_h.fetch("amount_cents", 0)
      }
    end

    def time_entries_for(run)
      return TimeEntry.none unless run

      TimeEntry.joins(:employee).where(employees: { employer_id: @employer.id }).for_period(run.period_start_on, run.period_end_on)
    end

    def normalize_cadence(value)
      value.to_s.tr("-", "_") == "semi_monthly" ? "semimonthly" : value.to_s
    end

    def periods_per_year(cadence)
      {
        "weekly" => 52,
        "biweekly" => 26,
        "semimonthly" => 24,
        "monthly" => 12
      }.fetch(cadence, 26)
    end

    def deadline_at(pay_date, zone:, days_before:, hour:)
      (pay_date - days_before.days).in_time_zone(zone).change(hour:, min: 0)
    end
  end
end
