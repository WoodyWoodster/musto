module Contractors
  BatchHoldbackDto = Data.define(:payment_id, :contractor_id, :contractor_name, :description, :status, :amount_cents, :reason) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys

      new(
        payment_id: attributes.fetch("payment_id"),
        contractor_id: attributes.fetch("contractor_id"),
        contractor_name: attributes.fetch("contractor_name"),
        description: attributes.fetch("description"),
        status: attributes.fetch("status"),
        amount_cents: attributes.fetch("amount_cents"),
        reason: attributes.fetch("reason")
      )
    end
  end
end
