module Expenses
  BatchHoldbackDto = Data.define(:expense_id, :employee_id, :employee_name, :merchant, :category, :status, :amount_cents, :reason) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys

      new(
        expense_id: attributes.fetch("expense_id"),
        employee_id: attributes.fetch("employee_id"),
        employee_name: attributes.fetch("employee_name"),
        merchant: attributes.fetch("merchant"),
        category: attributes.fetch("category"),
        status: attributes.fetch("status"),
        amount_cents: attributes.fetch("amount_cents"),
        reason: attributes.fetch("reason")
      )
    end
  end
end
