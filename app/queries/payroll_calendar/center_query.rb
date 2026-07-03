module PayrollCalendar
  class CenterQuery
    def initialize(employer_repository: Employers::EmployerRepository.new)
      @employer = employer_repository.first_for_operations
      @repository = CalendarRepository.new(employer: @employer)
    end

    def call
      schedule = @repository.current_schedule
      run = @repository.current_run
      steps = @repository.approval_steps.to_a
      checklists = @repository.checklists
      latest_checklist = checklists.first.to_h

      CenterDto.new(
        employer: Operations::EmployerContextDto.from_record(@employer),
        schedule: ScheduleDto.from_record(schedule),
        payroll_run: RunDto.from_record(run),
        metrics: metrics(schedule, run, steps),
        approval_steps: steps.map { |step| ApprovalStepDto.from_record(step) },
        calendar_events: calendar_events(schedule, run),
        risks: risks(schedule, run, steps),
        checklists: checklists.map { |payload| ChecklistDto.from_hash(payload) },
        checklist_lines: latest_checklist.fetch("lines", []).map { |payload| ChecklistLineDto.from_hash(payload) },
        checklist_payload: checklists.first
      )
    end

    private

    def metrics(schedule, run, steps)
      completed_count = steps.count(&:completed?)
      total_steps = steps.count
      blocked_steps = steps.count(&:blocked?)
      blocker_records = run ? blocker_record_count(run) : 1
      days_until_payday = schedule&.days_until_payday || 0

      [
        MetricDto.new(label: "Days to payday", value: days_until_payday, hint: schedule ? "#{schedule.next_pay_date.strftime('%b %-d, %Y')} payroll" : "No schedule configured", status: schedule ? deadline_status(schedule.next_pay_date.in_time_zone) : "blocked", accent: "bg-indigo-500", format: "number"),
        MetricDto.new(label: "Approval steps", value: completed_count, hint: "#{total_steps} controls on the checklist", status: total_steps.positive? && completed_count == total_steps ? "ready" : "in_progress", accent: "bg-cyan-500", format: "number"),
        MetricDto.new(label: "Open blockers", value: blocked_steps + blocker_records, hint: "#{blocked_steps} blocked controls plus #{blocker_records} data blockers", status: blocked_steps.positive? || blocker_records.positive? ? "needs_review" : "ready", accent: "bg-rose-500", format: "number"),
        MetricDto.new(label: "Net pay exposure", value: run&.estimated_net_pay_cents.to_i, hint: run ? "current run estimate" : "no current payroll run", status: run ? "ready" : "blocked", accent: "bg-emerald-500", format: "money")
      ]
    end

    def calendar_events(schedule, run)
      return [] unless schedule

      events = [
        CalendarEventDto.new(key: "approval_deadline", title: "Approval deadline", detail: "Managers, payroll, benefits, and finance controls must be certified.", event_at: schedule.approval_deadline_at, status: deadline_status(schedule.approval_deadline_at), owner: "Payroll", kind: "approval"),
        CalendarEventDto.new(key: "funding_deadline", title: "Funding deadline", detail: "ACH funding and direct deposit readiness must be locked.", event_at: schedule.funding_deadline_at, status: deadline_status(schedule.funding_deadline_at), owner: "Finance", kind: "funding"),
        CalendarEventDto.new(key: "payday", title: "Payday", detail: "Employee pay statements and net pay disbursement are due.", event_at: schedule.next_pay_date.in_time_zone(schedule.timezone).change(hour: 9), status: deadline_status(schedule.next_pay_date.in_time_zone(schedule.timezone)), owner: "Payroll", kind: "payday")
      ]

      if run
        events << CalendarEventDto.new(key: "benefits_export", title: "Vitable deductions export", detail: "#{run.payroll_deductions.count} benefit deductions tied to this payroll run.", event_at: schedule.approval_deadline_at - 2.hours, status: @repository.waiting_deductions_for(run).exists? ? "needs_review" : "ready", owner: "Benefits", kind: "integration")
      end

      events.sort_by(&:event_at)
    end

    def risks(schedule, run, steps)
      routes = Rails.application.routes.url_helpers
      items = []

      if schedule.blank?
        items << RiskDto.new(key: "missing_schedule", title: "Create payroll schedule", detail: "Payroll needs a recurring schedule before cutoff, approval, funding, and pay date controls can be trusted.", severity: "critical", status: "blocked", owner: "Payroll", count: 1, amount_cents: 0, action_path: routes.payroll_calendar_path)
      end

      if run.blank?
        items << RiskDto.new(key: "missing_run", title: "Create payroll run", detail: "No current payroll run exists for the calendar to coordinate.", severity: "critical", status: "blocked", owner: "Payroll", count: 1, amount_cents: 0, action_path: routes.payroll_path)
        return items
      end

      submitted_time = @repository.submitted_time_entries_for(run)
      waiting_deductions = @repository.waiting_deductions_for(run)
      pending_accounts = @repository.pending_employee_accounts
      blocked_accounts = @repository.blocked_employee_accounts
      overdue_steps = steps.select(&:overdue?)

      if submitted_time.exists?
        items << RiskDto.new(key: "submitted_time", title: "Approve submitted time entries", detail: "#{submitted_time.count} time entries are submitted and will block payroll close until reviewed.", severity: "high", status: "blocked", owner: "Managers", count: submitted_time.count, amount_cents: 0, action_path: routes.timesheets_path)
      end

      if waiting_deductions.exists?
        items << RiskDto.new(key: "vitable_deductions", title: "Clear Vitable deduction holds", detail: "#{waiting_deductions.count} deductions are waiting on enrollment decisions or remote benefit sync.", severity: "high", status: "blocked", owner: "Benefits", count: waiting_deductions.count, amount_cents: waiting_deductions.sum(:amount_cents), action_path: routes.benefits_path)
      end

      unless @repository.employer_funding_ready?
        items << RiskDto.new(key: "funding_source", title: "Verify employer funding account", detail: "A verified company funding account is required before payroll ACH generation.", severity: "critical", status: "blocked", owner: "Finance", count: 1, amount_cents: run.estimated_net_pay_cents, action_path: routes.payroll_funding_path)
      end

      if pending_accounts.exists? || blocked_accounts.exists?
        count = pending_accounts.count + blocked_accounts.count
        items << RiskDto.new(key: "direct_deposit", title: "Resolve direct deposit readiness", detail: "#{count} employee bank accounts need verification or unblock review.", severity: blocked_accounts.exists? ? "high" : "medium", status: "blocked", owner: "People Ops", count:, amount_cents: 0, action_path: routes.payroll_funding_path)
      end

      if overdue_steps.any?
        items << RiskDto.new(key: "overdue_controls", title: "Complete overdue payroll controls", detail: "#{overdue_steps.count} approval controls are past due for this payroll run.", severity: "high", status: "needs_review", owner: "Payroll", count: overdue_steps.count, amount_cents: run.estimated_net_pay_cents, action_path: routes.payroll_calendar_path)
      end

      return items if items.any?

      [
        RiskDto.new(key: "calendar_ready", title: "Payroll calendar is ready", detail: "Cutoffs, funding checks, Vitable deductions, and approval controls are clear for this run.", severity: "low", status: "ready", owner: "Payroll", count: steps.count, amount_cents: run.estimated_net_pay_cents, action_path: routes.payroll_calendar_path)
      ]
    end

    def blocker_record_count(run)
      @repository.submitted_time_entries_for(run).count +
        @repository.waiting_deductions_for(run).count +
        @repository.pending_employee_accounts.count +
        @repository.blocked_employee_accounts.count +
        (@repository.employer_funding_ready? ? 0 : 1)
    end

    def deadline_status(value)
      return "overdue" if value < Time.current
      return "due_soon" if value < 2.days.from_now

      "scheduled"
    end
  end
end
