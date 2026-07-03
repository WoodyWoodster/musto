module Taxes
  AgencyRegistrationPacketDto = Data.define(
    :packet_id,
    :generated_at,
    :requested_by,
    :status,
    :registration_count,
    :ready_count,
    :submitted_count,
    :registered_count,
    :holdback_count,
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
        registration_count: totals.fetch("registration_count", 0),
        ready_count: totals.fetch("ready_count", 0),
        submitted_count: totals.fetch("submitted_count", 0),
        registered_count: totals.fetch("registered_count", 0),
        holdback_count: totals.fetch("holdback_count", 0),
        jurisdiction_count: totals.fetch("jurisdiction_count", 0)
      )
    end
  end
end
