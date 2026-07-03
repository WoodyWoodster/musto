module Operations
  PayrollAdjustmentDto = Data.define(:id, :description, :employee_name, :adjustment_type, :amount_cents, :taxable) do
    def self.from_record(record)
      new(
        id: record.id,
        description: record.description,
        employee_name: record.employee.full_name,
        adjustment_type: record.adjustment_type,
        amount_cents: record.amount_cents,
        taxable: record.taxable?
      )
    end

    def taxable?
      taxable
    end
  end
end
