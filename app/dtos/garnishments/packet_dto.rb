module Garnishments
  PacketDto = Data.define(
    :packet_id,
    :generated_at,
    :requested_by,
    :status,
    :payroll_run_id,
    :pay_date,
    :order_count,
    :remittance_count,
    :agency_count,
    :holdback_count,
    :total_withheld_cents,
    :disposable_earnings_cents
  ) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys
      totals = attributes.fetch("totals", {}).to_h.stringify_keys

      new(
        packet_id: attributes.fetch("packet_id"),
        generated_at: Time.iso8601(attributes.fetch("generated_at")),
        requested_by: attributes.fetch("requested_by", "ops_console"),
        status: attributes.fetch("status", "needs_review"),
        payroll_run_id: attributes.fetch("payroll_run_id", nil),
        pay_date: Date.iso8601(attributes.fetch("pay_date")),
        order_count: totals.fetch("order_count", 0),
        remittance_count: totals.fetch("remittance_count", 0),
        agency_count: totals.fetch("agency_count", 0),
        holdback_count: totals.fetch("holdback_count", 0),
        total_withheld_cents: totals.fetch("total_withheld_cents", 0),
        disposable_earnings_cents: totals.fetch("disposable_earnings_cents", 0)
      )
    end
  end
end
