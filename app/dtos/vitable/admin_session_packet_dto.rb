module Vitable
  AdminSessionPacketDto = Data.define(
    :packet_id,
    :generated_at,
    :requested_by,
    :employer_id,
    :remote_employer_id,
    :status,
    :widget_count,
    :holdback_count,
    :endpoint
  ) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys
      totals = attributes.fetch("totals", {}).to_h.stringify_keys
      token_request = attributes.fetch("token_request", {}).to_h.stringify_keys

      new(
        packet_id: attributes.fetch("packet_id"),
        generated_at: Time.iso8601(attributes.fetch("generated_at")),
        requested_by: attributes.fetch("requested_by", "ops_console"),
        employer_id: attributes.fetch("employer_id"),
        remote_employer_id: attributes.fetch("remote_employer_id", nil),
        status: attributes.fetch("status"),
        widget_count: totals.fetch("widget_count", 0),
        holdback_count: totals.fetch("holdback_count", 0),
        endpoint: token_request.fetch("endpoint", "/v1/auth/access-tokens")
      )
    end
  end
end
