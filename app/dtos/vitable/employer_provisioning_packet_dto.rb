module Vitable
  EmployerProvisioningPacketDto = Data.define(
    :packet_id,
    :generated_at,
    :requested_by,
    :employer_id,
    :remote_employer_id,
    :endpoint,
    :mode,
    :status,
    :payload_field_count,
    :missing_field_count,
    :holdback_count
  ) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys
      totals = attributes.fetch("totals", {}).to_h.stringify_keys

      new(
        packet_id: attributes.fetch("packet_id"),
        generated_at: Time.iso8601(attributes.fetch("generated_at")),
        requested_by: attributes.fetch("requested_by", "ops_console"),
        employer_id: attributes.fetch("employer_id"),
        remote_employer_id: attributes.fetch("remote_employer_id", nil),
        endpoint: attributes.fetch("endpoint"),
        mode: attributes.fetch("mode"),
        status: attributes.fetch("status"),
        payload_field_count: totals.fetch("payload_field_count", 0),
        missing_field_count: totals.fetch("missing_field_count", 0),
        holdback_count: totals.fetch("holdback_count", 0)
      )
    end
  end
end
