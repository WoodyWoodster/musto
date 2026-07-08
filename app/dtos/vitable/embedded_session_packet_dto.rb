module Vitable
  EmbeddedSessionPacketDto = Data.define(
    :packet_id,
    :generated_at,
    :requested_by,
    :employer_id,
    :enrollment_widget,
    :status,
    :employee_count,
    :ready_count,
    :holdback_count,
    :pending_election_count,
    :endpoint,
    :authorization_header
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
        enrollment_widget: attributes.fetch("enrollment_widget", "embedded"),
        status: attributes.fetch("status"),
        employee_count: totals.fetch("employee_count", 0),
        ready_count: totals.fetch("ready_count", 0),
        holdback_count: totals.fetch("holdback_count", 0),
        pending_election_count: totals.fetch("pending_election_count", 0),
        endpoint: token_request.fetch("endpoint", "/v1/auth/access-tokens"),
        authorization_header: token_request.fetch("authorization_header", "X-Musto-Widget-Launch")
      )
    end
  end
end
