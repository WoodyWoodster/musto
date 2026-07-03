module Contractors
  BatchDto = Data.define(
    :batch_id,
    :generated_at,
    :status,
    :requested_by,
    :payment_count,
    :total_cents,
    :holdback_count,
    :contractor_count
  ) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys
      totals = attributes.fetch("totals", {}).to_h.stringify_keys

      new(
        batch_id: attributes.fetch("batch_id"),
        generated_at: Time.iso8601(attributes.fetch("generated_at")),
        status: attributes.fetch("status"),
        requested_by: attributes.fetch("requested_by", "ops_console"),
        payment_count: totals.fetch("payment_count", 0),
        total_cents: totals.fetch("total_cents", 0),
        holdback_count: totals.fetch("holdback_count", 0),
        contractor_count: totals.fetch("contractor_count", 0)
      )
    end
  end
end
