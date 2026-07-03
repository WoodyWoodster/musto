module Benefits
  OffboardingPacketDto = Data.define(:packet_id, :generated_at, :requested_by, :status, :event_count, :member_count, :employee_count, :holdback_count) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys
      totals = attributes.fetch("totals", {}).to_h.stringify_keys

      new(
        packet_id: attributes.fetch("packet_id"),
        generated_at: Time.iso8601(attributes.fetch("generated_at")),
        requested_by: attributes.fetch("requested_by", "benefits_admin"),
        status: attributes.fetch("status"),
        event_count: totals.fetch("event_count", 0),
        member_count: totals.fetch("member_count", 0),
        employee_count: totals.fetch("employee_count", 0),
        holdback_count: totals.fetch("holdback_count", 0)
      )
    end
  end
end
