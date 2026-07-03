module TimeOff
  AccrualPacketDto = Data.define(:packet_id, :generated_at, :requested_by, :status, :line_count, :holdback_count, :accrual_hours, :usage_hours) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys
      totals = attributes.fetch("totals", {}).to_h.stringify_keys

      new(
        packet_id: attributes.fetch("packet_id"),
        generated_at: Time.iso8601(attributes.fetch("generated_at")),
        requested_by: attributes.fetch("requested_by", "payroll_admin"),
        status: attributes.fetch("status"),
        line_count: totals.fetch("line_count", 0),
        holdback_count: totals.fetch("holdback_count", 0),
        accrual_hours: totals.fetch("accrual_hours", 0),
        usage_hours: totals.fetch("usage_hours", 0)
      )
    end
  end
end
