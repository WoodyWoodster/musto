module TimeOff
  class AccrualRepository < ApplicationRepository
    PACKET_KEY = "pto_payroll_packet"

    def initialize(employer:)
      @employer = employer
    end

    def policies
      return TimeOffPolicy.none unless @employer

      @employer.time_off_policies.active.order(:name)
    end

    def employees
      return Employee.none unless @employer

      @employer.employees.active.includes(:department, :work_location).order(:last_name, :first_name)
    end

    def accruals
      return TimeOffAccrual.none unless @employer

      TimeOffAccrual
        .joins(:employee)
        .where(employees: { employer_id: @employer.id })
        .includes(:employee, :time_off_policy, :payroll_run)
        .recent_first
    end

    def requests
      return TimeOffRequest.none unless @employer

      TimeOffRequest
        .joins(:employee)
        .where(employees: { employer_id: @employer.id })
        .includes(:employee, :time_off_policy)
        .order(starts_on: :desc)
    end

    def latest_packet
      @employer&.settings.to_h.fetch(PACKET_KEY, nil)
    end

    def current_payroll_run
      @employer&.payroll_runs&.order(pay_date: :desc)&.first
    end

    def find_accrual(id)
      accruals.find(id)
    end

    def generate_monthly_accruals(period_start_on:, requested_by:)
      period_start_on = period_start_on.beginning_of_month
      period_end_on = period_start_on.end_of_month
      run = payroll_run_for_period(period_start_on, period_end_on)

      employees.flat_map do |employee|
        policies.filter_map do |policy|
          hours = monthly_accrual_hours(policy)
          next if hours.zero?

          accrual = TimeOffAccrual.find_or_initialize_by(
            employee:,
            time_off_policy: policy,
            period_start_on:,
            accrual_type: "monthly_accrual"
          )
          accrual.assign_attributes(
            payroll_run: run,
            hours:,
            period_end_on:,
            effective_on: period_end_on,
            source: "system",
            status: accrual.status == "approved" ? "approved" : "pending",
            metadata: accrual.metadata.to_h.merge(
              "requested_by" => requested_by,
              "generated_from" => "pto_accrual_ledger",
              "generated_at" => Time.current.iso8601
            )
          )
          accrual.save!
          accrual
        end
      end
    end

    def approve_accrual(accrual, approved_by:)
      accrual.update!(
        status: "approved",
        approved_at: Time.current,
        metadata: accrual.metadata.to_h.merge(
          "approved_by" => approved_by,
          "approved_from" => "pto_accrual_ledger",
          "approved_at" => Time.current.iso8601
        )
      )
    end

    def generate_payroll_packet(requested_by:)
      run = current_payroll_run
      period_start_on = run&.period_start_on || Date.current.beginning_of_month
      period_end_on = run&.period_end_on || Date.current.end_of_month
      approved_accruals = accruals.select { |accrual| accrual.status == "approved" && accrual.effective_on.between?(period_start_on, period_end_on) }
      approved_requests = requests.select { |request| request.status == "approved" && request.starts_on <= period_end_on && request.ends_on >= period_start_on }
      pending_items = accruals.select { |accrual| accrual.status == "pending" && accrual.effective_on.between?(period_start_on, period_end_on) } +
        requests.select { |request| request.status == "requested" && request.starts_on <= period_end_on && request.ends_on >= period_start_on }
      lines = approved_accruals.map { |accrual| accrual_packet_line(accrual) } + approved_requests.map { |request| request_packet_line(request) }
      holdbacks = pending_items.map { |item| holdback_line(item) }
      packet = {
        "packet_id" => "pto_payroll_#{@employer.id}_#{run&.id || 'adhoc'}_#{Time.current.to_i}",
        "generated_at" => Time.current.iso8601,
        "requested_by" => requested_by,
        "employer_id" => @employer.id,
        "payroll_run_id" => run&.id,
        "period_start_on" => period_start_on.iso8601,
        "period_end_on" => period_end_on.iso8601,
        "status" => holdbacks.any? ? "needs_review" : "ready",
        "totals" => {
          "line_count" => lines.count,
          "holdback_count" => holdbacks.count,
          "accrual_hours" => approved_accruals.sum(&:hours),
          "usage_hours" => approved_requests.sum(&:hours)
        },
        "lines" => lines,
        "holdbacks" => holdbacks
      }

      @employer.update!(settings: @employer.settings.to_h.merge(PACKET_KEY => packet))
      packet
    end

    private

    def monthly_accrual_hours(policy)
      (policy.annual_hours / 12).round(2)
    end

    def payroll_run_for_period(period_start_on, period_end_on)
      @employer
        .payroll_runs
        .where("period_start_on <= ? AND period_end_on >= ?", period_end_on, period_start_on)
        .order(pay_date: :desc)
        .first
    end

    def accrual_packet_line(accrual)
      {
        "line_type" => "accrual_credit",
        "employee_id" => accrual.employee_id,
        "employee_name" => accrual.employee.full_name,
        "policy_name" => accrual.time_off_policy.name,
        "hours" => accrual.hours,
        "payroll_action" => "credit_balance",
        "status" => "ready"
      }
    end

    def request_packet_line(request)
      {
        "line_type" => "pto_usage",
        "employee_id" => request.employee_id,
        "employee_name" => request.employee.full_name,
        "policy_name" => request.time_off_policy.name,
        "hours" => request.hours,
        "payroll_action" => "record_paid_time_off",
        "status" => "ready"
      }
    end

    def holdback_line(item)
      if item.is_a?(TimeOffAccrual)
        {
          "employee_id" => item.employee_id,
          "employee_name" => item.employee.full_name,
          "policy_name" => item.time_off_policy.name,
          "status" => "needs_review",
          "reason_code" => "pending_accrual",
          "reason" => "Accrual credit must be approved before payroll export."
        }
      else
        {
          "employee_id" => item.employee_id,
          "employee_name" => item.employee.full_name,
          "policy_name" => item.time_off_policy.name,
          "status" => "needs_review",
          "reason_code" => "pending_time_off_request",
          "reason" => "Time-off request must be reviewed before payroll export."
        }
      end
    end
  end
end
