module Compliance
  NoticePacketDto = Data.define(
    :packet_id,
    :generated_at,
    :requested_by,
    :status,
    :notice_count,
    :open_count,
    :ready_count,
    :holdback_count,
    :amount_cents,
    :jurisdiction_count
  ) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys
      totals = attributes.fetch("totals", {}).to_h.stringify_keys

      new(
        packet_id: attributes.fetch("packet_id"),
        generated_at: Time.iso8601(attributes.fetch("generated_at")),
        requested_by: attributes.fetch("requested_by", "ops_console"),
        status: attributes.fetch("status"),
        notice_count: totals.fetch("notice_count", 0),
        open_count: totals.fetch("open_count", 0),
        ready_count: totals.fetch("ready_count", 0),
        holdback_count: totals.fetch("holdback_count", 0),
        amount_cents: totals.fetch("amount_cents", 0),
        jurisdiction_count: totals.fetch("jurisdiction_count", 0)
      )
    end
  end
end
