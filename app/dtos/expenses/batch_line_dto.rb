module Expenses
  BatchLineDto = Data.define(:expense_id, :employee_id, :employee_name, :department_name, :merchant, :category, :incurred_on, :payment_method, :amount_cents) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys

      new(
        expense_id: attributes.fetch("expense_id"),
        employee_id: attributes.fetch("employee_id"),
        employee_name: attributes.fetch("employee_name"),
        department_name: attributes.fetch("department_name", "Unassigned"),
        merchant: attributes.fetch("merchant"),
        category: attributes.fetch("category"),
        incurred_on: Date.iso8601(attributes.fetch("incurred_on")),
        payment_method: attributes.fetch("payment_method"),
        amount_cents: attributes.fetch("amount_cents")
      )
    end
  end
end
