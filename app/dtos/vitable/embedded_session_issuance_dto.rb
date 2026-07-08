module Vitable
  EmbeddedSessionIssuanceDto = Data.define(
    :status,
    :issued_at,
    :expires_at,
    :expires_in,
    :token_type,
    :bound_entity,
    :sync_run_id,
    :token_present
  ) do
    def self.from_response(response_hash, issued_at:, sync_run_id:)
      attributes = response_hash.to_h.stringify_keys
      expires_in = attributes.fetch("expires_in", nil)

      new(
        status: "issued",
        issued_at:,
        expires_at: expires_in.present? ? issued_at + expires_in.to_i.seconds : nil,
        expires_in:,
        token_type: attributes.fetch("token_type", nil),
        bound_entity: attributes.fetch("bound_entity", {}).to_h.stringify_keys,
        sync_run_id:,
        token_present: attributes.fetch("access_token", nil).present?
      )
    end

    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys

      new(
        status: attributes.fetch("status", "pending"),
        issued_at: parse_time(attributes.fetch("issued_at", nil)),
        expires_at: parse_time(attributes.fetch("expires_at", nil)),
        expires_in: attributes.fetch("expires_in", nil),
        token_type: attributes.fetch("token_type", nil),
        bound_entity: attributes.fetch("bound_entity", {}).to_h.stringify_keys,
        sync_run_id: attributes.fetch("sync_run_id", nil),
        token_present: attributes.fetch("token_present", false)
      )
    end

    def to_metadata
      {
        "status" => status,
        "issued_at" => issued_at&.iso8601,
        "expires_at" => expires_at&.iso8601,
        "expires_in" => expires_in,
        "token_type" => token_type,
        "bound_entity" => bound_entity,
        "sync_run_id" => sync_run_id,
        "token_present" => token_present
      }.compact
    end

    def self.parse_time(value)
      return value if value.respond_to?(:iso8601)
      return if value.blank?

      Time.iso8601(value.to_s)
    rescue ArgumentError
      nil
    end

    private_class_method :parse_time
  end
end
