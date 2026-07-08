require "json"

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

    def self.error_message(error)
      new.error_message(error)
    end

    def self.error_with_class(error)
      "#{error.class}: #{error_message(error)}"
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

    def error_message(error)
      return if error.blank?

      return api_error_message(error) if error.respond_to?(:body) && !error.body.nil?

      redact_text(error.message)
    end

    private

    def api_error_message(error)
      message = "Vitable API request failed"
      message = "#{message} with status #{error.status}" if error.respond_to?(:status) && error.status.present?

      body = normalized_payload(error.body)
      return message if body.blank?

      "#{message}: #{JSON.generate(redact(body).deep_stringify_keys)}"
    end

    def normalized_payload(value)
      case value
      when nil
        {}
      when Hash
        value
      when Array
        { data: value }
      when String
        parsed_json_payload(value) || { value: redact_text(value) }
      when Numeric, TrueClass, FalseClass
        { value: value }
      else
        if value.respond_to?(:deep_to_h)
          value.deep_to_h
        elsif value.respond_to?(:to_h)
          value.to_h
        else
          { value: redact_text(value.to_s) }
        end
      end
    end

    def parsed_json_payload(value)
      JSON.parse(value)
    rescue JSON::ParserError
      nil
    end

    def redact_text(value)
      value.to_s.gsub(/\bvit_[a-z0-9]+_[A-Za-z0-9_-]+\b/i, FILTERED)
    end

    def sensitive_key?(key)
      normalized = key.downcase
      SENSITIVE_KEYS.include?(normalized) || normalized.end_with?("_token", "_secret")
    end
  end
end
