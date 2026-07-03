module PayStatements
  StatementDto = Data.define(
    :id,
    :payroll_run_id,
    :employee_id,
    :employee_name,
    :department_name,
    :location_name,
    :statement_number,
    :period_start_on,
    :period_end_on,
    :pay_date,
    :gross_pay_cents,
    :adjustment_cents,
    :deduction_cents,
    :tax_cents,
    :net_pay_cents,
    :status,
    :delivery_method,
    :delivered_at,
    :viewed_at
  ) do
    def self.from_record(record)
      employee = record.employee

      new(
        id: record.id,
        payroll_run_id: record.payroll_run_id,
        employee_id: record.employee_id,
        employee_name: employee.full_name,
        department_name: employee.department&.name || "Unassigned",
        location_name: employee.work_location&.name || "No location",
        statement_number: record.statement_number,
        period_start_on: record.period_start_on,
        period_end_on: record.period_end_on,
        pay_date: record.pay_date,
        gross_pay_cents: record.gross_pay_cents,
        adjustment_cents: record.adjustment_cents,
        deduction_cents: record.deduction_cents,
        tax_cents: record.tax_cents,
        net_pay_cents: record.net_pay_cents,
        status: record.status,
        delivery_method: record.delivery_method,
        delivered_at: record.delivered_at,
        viewed_at: record.viewed_at
      )
    end

    def generated?
      status == "generated"
    end

    def delivered?
      %w[delivered viewed].include?(status)
    end

    def viewed?
      status == "viewed"
    end
  end
end
