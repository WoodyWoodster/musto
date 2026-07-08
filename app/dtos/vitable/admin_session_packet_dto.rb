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
    :endpoint,
    :authorization_header,
    :launch_token,
    :launch_token_present,
    :launch_token_expires_at
  ) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys
      totals = attributes.fetch("totals", {}).to_h.stringify_keys
      token_request = attributes.fetch("token_request", {}).to_h.stringify_keys
      launch_authorization = attributes.fetch("launch_authorization", {}).to_h.stringify_keys

      new(
        packet_id: attributes.fetch("packet_id"),
        generated_at: Time.iso8601(attributes.fetch("generated_at")),
        requested_by: attributes.fetch("requested_by", "ops_console"),
        employer_id: attributes.fetch("employer_id"),
        remote_employer_id: attributes.fetch("remote_employer_id", nil),
        status: attributes.fetch("status"),
        widget_count: totals.fetch("widget_count", 0),
        holdback_count: totals.fetch("holdback_count", 0),
        endpoint: token_request.fetch("endpoint", EndpointCatalog::AUTH_ACCESS_TOKENS),
        authorization_header: token_request.fetch("authorization_header", "X-Musto-Widget-Launch"),
        launch_token: launch_authorization.fetch("token", nil),
        launch_token_present: launch_authorization.fetch("token", nil).present?,
        launch_token_expires_at: parse_time(launch_authorization.fetch("expires_at", nil))
      )
    end

    def launch_token_active?(at: Time.current)
      launch_token_present && launch_token_expires_at.present? && launch_token_expires_at > at
    end

    def self.parse_time(value)
      return value if value.respond_to?(:iso8601)
      return if value.blank?

      Time.iso8601(value.to_s)
    rescue ArgumentError
      nil
    end
  end
end
