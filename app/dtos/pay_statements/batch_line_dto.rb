module PayStatements
  BatchLineDto = Data.define(:statement_id, :statement_number, :employee_id, :employee_name, :gross_pay_cents, :deduction_cents, :tax_cents, :net_pay_cents, :status) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys

      new(
        statement_id: attributes.fetch("statement_id"),
        statement_number: attributes.fetch("statement_number"),
        employee_id: attributes.fetch("employee_id"),
        employee_name: attributes.fetch("employee_name"),
        gross_pay_cents: attributes.fetch("gross_pay_cents"),
        deduction_cents: attributes.fetch("deduction_cents"),
        tax_cents: attributes.fetch("tax_cents"),
        net_pay_cents: attributes.fetch("net_pay_cents"),
        status: attributes.fetch("status")
      )
    end
  end
end
