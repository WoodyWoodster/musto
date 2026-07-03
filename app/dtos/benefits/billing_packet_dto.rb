module Benefits
  BillingPacketDto = Data.define(:packet_id, :generated_at, :requested_by, :status, :invoice_id, :payment_count, :holdback_count, :total_cents) do
    def self.from_hash(payload)
      totals = payload.to_h.fetch("totals", {})

      new(
        packet_id: payload.fetch("packet_id"),
        generated_at: Time.zone.parse(payload.fetch("generated_at")),
        requested_by: payload.fetch("requested_by"),
        status: payload.fetch("status"),
        invoice_id: payload.fetch("invoice_id"),
        payment_count: totals.fetch("payment_count", 0),
        holdback_count: totals.fetch("holdback_count", 0),
        total_cents: totals.fetch("total_cents", 0)
      )
    end
  end
end
