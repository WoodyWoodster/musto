module TimeOff
  AccrualBalanceDto = Data.define(:employee_id, :employee_name, :department_name, :policy_count, :approved_accrual_hours, :pending_accrual_hours, :approved_usage_hours, :remaining_hours, :status) do
    def self.from_employee(employee, policies, accruals, requests)
      employee_accruals = accruals.select { |accrual| accrual.employee_id == employee.id }
      employee_requests = requests.select { |request| request.employee_id == employee.id }
      approved_accrual_hours = employee_accruals.select { |accrual| accrual.status == "approved" }.sum(&:hours)
      pending_accrual_hours = employee_accruals.select { |accrual| accrual.status == "pending" }.sum(&:hours)
      approved_usage_hours = employee_requests.select { |request| request.status == "approved" }.sum(&:hours)
      remaining_hours = approved_accrual_hours - approved_usage_hours

      new(
        employee_id: employee.id,
        employee_name: employee.full_name,
        department_name: employee.department&.name || "Unassigned",
        policy_count: policies.count,
        approved_accrual_hours:,
        pending_accrual_hours:,
        approved_usage_hours:,
        remaining_hours:,
        status: status_for(remaining_hours, pending_accrual_hours)
      )
    end

    def needs_attention?
      status != "ready"
    end

    private_class_method def self.status_for(remaining_hours, pending_accrual_hours)
      return "blocked" if remaining_hours.negative?
      return "needs_review" if pending_accrual_hours.positive?

      "ready"
    end
  end
end
