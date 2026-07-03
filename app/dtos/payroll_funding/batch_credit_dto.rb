module PayrollFunding
  BatchCreditDto = Data.define(:employee_id, :employee_name, :employee_account_id, :institution_name, :account_last4, :amount_cents, :trace_code) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys

      new(
        employee_id: attributes.fetch("employee_id"),
        employee_name: attributes.fetch("employee_name"),
        employee_account_id: attributes.fetch("employee_account_id"),
        institution_name: attributes.fetch("institution_name"),
        account_last4: attributes.fetch("account_last4"),
        amount_cents: attributes.fetch("amount_cents"),
        trace_code: attributes.fetch("trace_code")
      )
    end
  end
end
