module Garnishments
  OrderDto = Data.define(
    :id,
    :employee_id,
    :employee_name,
    :employee_title,
    :department_name,
    :location_name,
    :title,
    :deduction_type,
    :status,
    :calculation_method,
    :amount_cents,
    :percent_basis_points,
    :max_per_paycheck_cents,
    :current_balance_cents,
    :estimated_amount_cents,
    :gross_cents,
    :disposable_earnings_cents,
    :priority,
    :agency_name,
    :case_number,
    :remittance_method,
    :service_state,
    :starts_on,
    :ends_on,
    :readiness_status,
    :readiness_reason
  ) do
    def self.from_record(record, repository:, payroll_run:)
      employee = record.employee

      new(
        id: record.id,
        employee_id: employee.id,
        employee_name: employee.full_name,
        employee_title: employee.title,
        department_name: employee.department&.name,
        location_name: employee.work_location&.name,
        title: record.title,
        deduction_type: record.deduction_type,
        status: record.status,
        calculation_method: record.calculation_method,
        amount_cents: record.amount_cents,
        percent_basis_points: record.percent_basis_points,
        max_per_paycheck_cents: record.max_per_paycheck_cents,
        current_balance_cents: record.current_balance_cents,
        estimated_amount_cents: repository.estimated_amount_for(record, pay_date: payroll_run&.pay_date || Date.current),
        gross_cents: repository.gross_cents_for(record),
        disposable_earnings_cents: repository.disposable_earnings_cents_for(record),
        priority: record.priority,
        agency_name: record.agency_name,
        case_number: record.case_number,
        remittance_method: record.metadata.to_h.fetch("remittance_method", "agency_ach"),
        service_state: record.metadata.to_h.fetch("service_state", employee.work_location&.state.presence || "Federal"),
        starts_on: record.starts_on,
        ends_on: record.ends_on,
        readiness_status: repository.readiness_status_for(record, payroll_run),
        readiness_reason: repository.readiness_reason_for(record, payroll_run)
      )
    end

    def active?
      status == "active"
    end

    def approvable?
      status.in?(%w[pending blocked])
    end

    def pausable?
      active?
    end

    def ready?
      readiness_status == "ready"
    end
  end
end
