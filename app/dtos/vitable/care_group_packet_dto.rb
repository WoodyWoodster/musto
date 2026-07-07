module Vitable
  CareGroupPacketDto = Data.define(
    :packet_id,
    :generated_at,
    :requested_by,
    :employer_id,
    :remote_group_id,
    :endpoint,
    :mode,
    :status,
    :payload_field_count,
    :missing_field_count,
    :holdback_count,
    :external_reference_id,
    :name
  ) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys
      totals = attributes.fetch("totals", {}).to_h.stringify_keys
      api_payload = attributes.fetch("api_payload", {}).to_h.stringify_keys

      new(
        packet_id: attributes.fetch("packet_id"),
        generated_at: Time.iso8601(attributes.fetch("generated_at")),
        requested_by: attributes.fetch("requested_by", "ops_console"),
        employer_id: attributes.fetch("employer_id"),
        remote_group_id: attributes.fetch("remote_group_id", nil),
        endpoint: attributes.fetch("endpoint"),
        mode: attributes.fetch("mode"),
        status: attributes.fetch("status"),
        payload_field_count: totals.fetch("payload_field_count", 0),
        missing_field_count: totals.fetch("missing_field_count", 0),
        holdback_count: totals.fetch("holdback_count", 0),
        external_reference_id: api_payload.fetch("external_reference_id", nil),
        name: api_payload.fetch("name", nil)
      )
    end
  end
end
