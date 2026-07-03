module YearEnd
  PacketDto = Data.define(
    :packet_id,
    :generated_at,
    :requested_by,
    :status,
    :tax_year,
    :form_count,
    :w2_count,
    :form_1099_count,
    :ready_count,
    :holdback_count,
    :gross_wages_cents,
    :contractor_payment_cents,
    :withholding_cents
  ) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys
      totals = attributes.fetch("totals", {}).to_h.stringify_keys

      new(
        packet_id: attributes.fetch("packet_id"),
        generated_at: Time.iso8601(attributes.fetch("generated_at")),
        requested_by: attributes.fetch("requested_by", "ops_console"),
        status: attributes.fetch("status"),
        tax_year: attributes.fetch("tax_year"),
        form_count: totals.fetch("form_count", 0),
        w2_count: totals.fetch("w2_count", 0),
        form_1099_count: totals.fetch("form_1099_count", 0),
        ready_count: totals.fetch("ready_count", 0),
        holdback_count: totals.fetch("holdback_count", 0),
        gross_wages_cents: totals.fetch("gross_wages_cents", 0),
        contractor_payment_cents: totals.fetch("contractor_payment_cents", 0),
        withholding_cents: totals.fetch("withholding_cents", 0)
      )
    end
  end
end
