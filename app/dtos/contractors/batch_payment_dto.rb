module Contractors
  BatchPaymentDto = Data.define(:payment_id, :contractor_id, :contractor_name, :business_name, :description, :payment_method, :pay_date, :amount_cents) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys

      new(
        payment_id: attributes.fetch("payment_id"),
        contractor_id: attributes.fetch("contractor_id"),
        contractor_name: attributes.fetch("contractor_name"),
        business_name: attributes.fetch("business_name", nil),
        description: attributes.fetch("description"),
        payment_method: attributes.fetch("payment_method"),
        pay_date: Date.iso8601(attributes.fetch("pay_date")),
        amount_cents: attributes.fetch("amount_cents")
      )
    end
  end
end
