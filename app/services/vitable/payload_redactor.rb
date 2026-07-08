module Vitable
  class PayloadRedactor
    FILTERED = "[FILTERED]"
    SENSITIVE_KEYS = %w[
      access_token
      api_key
      authorization
      client_secret
      id_token
      password
      refresh_token
      secret
      signature
    ].freeze

    def self.redact(value)
      new.redact(value)
    end

    def redact(value)
      case value
      when Hash
        value.to_h do |key, entry|
          normalized_key = key.to_s
          [ key, sensitive_key?(normalized_key) ? FILTERED : redact(entry) ]
        end
      when Array
        value.map { |entry| redact(entry) }
      else
        value
      end
    end

    private

    def sensitive_key?(key)
      normalized = key.downcase
      SENSITIVE_KEYS.include?(normalized) || normalized.end_with?("_token", "_secret")
    end
  end
end
