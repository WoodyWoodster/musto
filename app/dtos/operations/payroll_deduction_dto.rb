module Operations
  PayrollDeductionDto = Data.define(:id, :employee_name, :code, :amount_cents, :enrollment_name, :status) do
    def self.from_record(record)
      new(
        id: record.id,
        employee_name: record.employee.full_name,
        code: record.code,
        amount_cents: record.amount_cents,
        enrollment_name: record.enrollment&.benefit_plan&.name,
        status: record.status
      )
    end
  end
end
