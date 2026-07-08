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

    def self.token_attributes(response_hash)
      attributes = response_hash.to_h.stringify_keys
      attributes.fetch("data", attributes).to_h.stringify_keys
    end

    private_class_method :token_attributes
  end
end
