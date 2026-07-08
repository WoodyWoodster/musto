module Vitable
  RemoteAccessTokenResponseDto = Data.define(
    :access_token,
    :expires_in,
    :token_type,
    :raw_payload
  ) do
    def self.from_response(response_hash)
      attributes = response_hash.to_h.stringify_keys
      data = attributes.fetch("data", attributes)
      data = data.respond_to?(:to_h) ? data.to_h.stringify_keys : {}

      new(
        access_token: data.fetch("access_token", nil),
        expires_in: data.fetch("expires_in", nil),
        token_type: data.fetch("token_type", nil),
        raw_payload: data
      )
    end

    def validate!(response_label: "Vitable credential verification response")
      raise ArgumentError, "#{response_label} did not include an access token" if access_token.blank?
      raise ArgumentError, "#{response_label} did not include expires_in" if expires_in.blank?
      unless ApplicationDto.strict_positive_integer?(expires_in)
        raise ArgumentError, "#{response_label} returned invalid expires_in #{expires_in}"
      end
      raise ArgumentError, "#{response_label} did not include token_type" if token_type.blank?
      raise ArgumentError, "#{response_label} returned token_type #{token_type}, expected Bearer" unless token_type.to_s.casecmp("Bearer").zero?

      self
    end
  end
end
