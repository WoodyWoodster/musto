module PayStatements
  BatchHoldbackDto = Data.define(:employee_id, :employee_name, :amount_cents, :reason, :status) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys

      new(
        employee_id: attributes.fetch("employee_id"),
        employee_name: attributes.fetch("employee_name"),
        amount_cents: attributes.fetch("amount_cents"),
        reason: attributes.fetch("reason"),
        status: attributes.fetch("status")
      )
    end
  end
end
