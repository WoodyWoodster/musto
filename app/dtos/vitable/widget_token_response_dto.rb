module Vitable
  WidgetTokenResponseDto = Data.define(
    :access_token,
    :expires_in,
    :token_type,
    :bound_entity,
    :issued_at
  ) do
    def self.from_response(response_hash, issued_at:)
      attributes = token_attributes(response_hash)

      new(
        access_token: attributes.fetch("access_token", nil),
        expires_in: attributes.fetch("expires_in", nil),
        token_type: attributes.fetch("token_type", nil),
        bound_entity: attributes.fetch("bound_entity", {}).to_h.stringify_keys,
        issued_at:
      )
    end

    def to_h
      {
        "access_token" => access_token,
        "expires_in" => expires_in,
        "token_type" => token_type,
        "bound_entity" => bound_entity,
        "issued_at" => issued_at.iso8601
      }.compact
    end

    def to_metadata
      to_h.except("access_token").merge("token_present" => access_token.present?)
    end

    def validate_bound_entity!(expected_type:, expected_id:, response_label: "Vitable widget token response")
      return self if bound_entity.blank?

      if bound_entity.fetch("type", nil).to_s != expected_type.to_s
        raise ArgumentError, "#{response_label} returned bound entity type #{bound_entity.fetch("type", nil)}, expected #{expected_type}"
      end
      if expected_id.present? && bound_entity.fetch("id", nil).to_s != expected_id.to_s
        raise ArgumentError, "#{response_label} returned bound entity ID #{bound_entity.fetch("id", nil)}, expected #{expected_id}"
      end

      self
    end

    def validate!(expected_type:, expected_id:, response_label: "Vitable widget token response")
      raise ArgumentError, "#{response_label} did not include an access token" if access_token.blank?
      raise ArgumentError, "#{response_label} did not include expires_in" if expires_in.blank?
      raise ArgumentError, "#{response_label} returned invalid expires_in #{expires_in}" unless expires_in.to_i.positive?
      raise ArgumentError, "#{response_label} did not include token_type" if token_type.blank?
      raise ArgumentError, "#{response_label} returned token_type #{token_type}, expected Bearer" unless token_type.to_s.casecmp("Bearer").zero?
      raise ArgumentError, "#{response_label} did not include bound_entity" if bound_entity.blank?

      validate_bound_entity!(expected_type:, expected_id:, response_label:)
    end

    def self.token_attributes(response_hash)
      attributes = response_hash.to_h.stringify_keys
      attributes.fetch("data", attributes).to_h.stringify_keys
    end

    private_class_method :token_attributes
  end
end
