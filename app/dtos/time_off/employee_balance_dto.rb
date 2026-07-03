module TimeOff
  EmployeeBalanceDto = Data.define(
    :employee_id,
    :employee_name,
    :department_name,
    :work_location_name,
    :allowance_hours,
    :approved_hours,
    :scheduled_hours,
    :pending_hours,
    :remaining_hours,
    :utilization_percent,
    :status
  ) do
    def self.from_employee(employee, policies, requests)
      allowance_hours = policies.sum { |policy| policy.annual_hours + policy.carryover_hours }
      approved_hours = requests.select { |request| request.status == "approved" }.sum(&:hours)
      scheduled_hours = requests.select { |request| request.status == "approved" && request.starts_on >= Date.current }.sum(&:hours)
      pending_hours = requests.select { |request| request.status == "requested" }.sum(&:hours)
      remaining_hours = [ allowance_hours - approved_hours, 0 ].max

      new(
        employee_id: employee.id,
        employee_name: employee.full_name,
        department_name: employee.department&.name,
        work_location_name: employee.work_location&.name,
        allowance_hours:,
        approved_hours:,
        scheduled_hours:,
        pending_hours:,
        remaining_hours:,
        utilization_percent: utilization_percent(allowance_hours, approved_hours),
        status: status_for(remaining_hours, pending_hours)
      )
    end

    def needs_attention?
      status != "ready"
    end

    def self.utilization_percent(allowance_hours, approved_hours)
      return 0 if allowance_hours.zero?

      ((approved_hours.to_f / allowance_hours.to_f) * 100).round
    end

    def self.status_for(remaining_hours, pending_hours)
      return "blocked" if pending_hours.positive? && pending_hours > remaining_hours
      return "needs_review" if pending_hours.positive? || remaining_hours < 16

      "ready"
    end

    private_class_method :utilization_percent, :status_for
  end
end
