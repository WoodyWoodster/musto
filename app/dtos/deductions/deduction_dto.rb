module Deductions
  DeductionDto = Data.define(:id, :employee_id, :employee_name, :employee_title, :department_name, :location_name, :title, :deduction_type, :status, :calculation_method, :amount_cents, :percent_basis_points, :max_per_paycheck_cents, :current_balance_cents, :estimated_amount_cents, :priority, :pre_tax, :agency_name, :case_number, :starts_on, :ends_on, :readiness_status, :readiness_reason) do
    def self.from_record(record, gross_cents:, pay_date: Date.current)
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
        estimated_amount_cents: record.estimated_amount_for(gross_cents, pay_date:),
        priority: record.priority,
        pre_tax: record.pre_tax?,
        agency_name: record.agency_name,
        case_number: record.case_number,
        starts_on: record.starts_on,
        ends_on: record.ends_on,
        readiness_status: readiness_status(record, pay_date:),
        readiness_reason: readiness_reason(record, pay_date:)
      )
    end

    def garnishment?
      deduction_type.in?(%w[child_support tax_levy creditor_garnishment])
    end

    def approvable?
      status.in?(%w[pending blocked])
    end

    def pausable?
      status == "active"
    end

    def active?
      status == "active"
    end

    private_class_method def self.readiness_status(record, pay_date:)
      return "ready" if record.ready_for_payroll?(pay_date:)
      return "needs_review" if record.pending?
      return "blocked" if record.blocked?
      return "paused" if record.paused?
      return "closed" if record.closed?

      "needs_review"
    end

    private_class_method def self.readiness_reason(record, pay_date:)
      return "Ready for payroll withholding" if record.ready_for_payroll?(pay_date:)
      return "Needs operator approval before payroll" if record.pending?
      return "Blocked pending court order, agency, or employee documentation" if record.blocked?
      return "Paused by payroll operations" if record.paused?
      return "Closed and excluded from payroll" if record.closed?
      return "Starts after the current pay date" if record.starts_on > pay_date

      "Needs payroll review"
    end
  end
end
