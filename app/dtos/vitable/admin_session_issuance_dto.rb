module Vitable
  AdminSessionIssuanceDto = Data.define(
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
      attributes = token_attributes(response_hash)
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
        status: attributes.fetch("status", "not_issued"),
        issued_at: parse_time(attributes.fetch("issued_at", nil)),
        expires_at: parse_time(attributes.fetch("expires_at", nil)),
        expires_in: attributes.fetch("expires_in", nil),
        token_type: attributes.fetch("token_type", nil),
        bound_entity: attributes.fetch("bound_entity", {}).to_h.stringify_keys,
        sync_run_id: attributes.fetch("sync_run_id", nil),
        token_present: attributes.fetch("token_present", false)
      )
    end

    def active?(at: Time.current)
      status == "issued" && expires_at.present? && expires_at > at
    end

    def validate_bound_entity!(expected_type:, expected_id:, response_label: "Vitable admin token response")
      return self if bound_entity.blank?

      if bound_entity.fetch("type", nil).to_s != expected_type.to_s
        raise ArgumentError, "#{response_label} returned bound entity type #{bound_entity.fetch("type", nil)}, expected #{expected_type}"
      end
      if expected_id.present? && bound_entity.fetch("id", nil).to_s != expected_id.to_s
        raise ArgumentError, "#{response_label} returned bound entity ID #{bound_entity.fetch("id", nil)}, expected #{expected_id}"
      end

      self
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

    def self.token_attributes(response_hash)
      attributes = response_hash.to_h.stringify_keys
      attributes.fetch("data", attributes).to_h.stringify_keys
    end

    private_class_method :token_attributes
  end
end
