require "openssl"

module Vitable
  class WebhookSignatureVerifier
    SIGNATURE_HEADERS = [
      "X-Vitable-Signature",
      "Vitable-Signature",
      "X-Vitable-Webhook-Signature"
    ].freeze
    TIMESTAMP_HEADERS = [ "X-Vitable-Timestamp", "Vitable-Timestamp" ].freeze

    def self.sign(raw_body:, secret:, timestamp: nil)
      signed_payload = timestamp.present? ? "#{timestamp}.#{raw_body}" : raw_body
      OpenSSL::HMAC.hexdigest("SHA256", secret, signed_payload)
    end

    def initialize(repository: IntegrationRepository.new, secret_lookup: ENV)
      @repository = repository
      @secret_lookup = secret_lookup
    end

    def verify(request)
      connection = connection_for(request)
      return result("unmatched_organization", "No matching Vitable connection was available for signature lookup.") unless connection
      return result("not_configured", "Webhook secret reference is not configured.", connection:) if connection.webhook_secret_reference.blank?

      secret = @secret_lookup.fetch(connection.webhook_secret_reference, nil)
      return result("secret_missing", "#{connection.webhook_secret_reference} is not available to the Rails process.", connection:) if secret.blank?

      signature_header, signature_value = signature_header(request)
      return result("missing_signature", "Webhook signature header is missing.", connection:) if signature_value.blank?

      timestamp = timestamp_header(request)
      return verified(connection:, header_name: signature_header, timestamp:) if valid_signature?(request.raw_body, secret, signature_value, timestamp)

      result("signature_invalid", "Webhook signature did not match the configured secret.", connection:, header_name: signature_header, timestamp:)
    end

    private

    def connection_for(request)
      external_id = request.payload.fetch("organization_id") { request.payload.fetch(:organization_id, nil) }
      return if external_id.blank?

      @repository.connection_for_organization_external_id(external_id)
    end

    def signature_header(request)
      SIGNATURE_HEADERS.each do |name|
        value = request.header(name)
        return [ name, value ] if value.present?
      end

      [ nil, nil ]
    end

    def timestamp_header(request)
      TIMESTAMP_HEADERS.filter_map { |name| request.header(name) }.first
    end

    def valid_signature?(raw_body, secret, signature_value, timestamp)
      expected = [
        self.class.sign(raw_body:, secret:),
        timestamp.present? ? self.class.sign(raw_body:, secret:, timestamp:) : nil
      ].compact

      signature_candidates(signature_value).any? do |candidate|
        expected.any? { |value| secure_compare(candidate, value) }
      end
    end

    def signature_candidates(value)
      value.to_s.split(",").flat_map do |part|
        normalized = part.strip
        key, candidate = normalized.split("=", 2)
        [ normalized, candidate, key == "sha256" ? candidate : nil, key == "v1" ? candidate : nil ]
      end.compact.uniq
    end

    def secure_compare(candidate, expected)
      candidate.bytesize == expected.bytesize && ActiveSupport::SecurityUtils.secure_compare(candidate, expected)
    end

    def verified(connection:, header_name:, timestamp:)
      result("verified", "Webhook signature matched #{connection.webhook_secret_reference}.", connection:, header_name:, timestamp:)
    end

    def result(status, detail, connection: nil, header_name: nil, timestamp: nil)
      WebhookSignatureVerificationDto.new(
        status:,
        detail:,
        connection_id: connection&.id,
        header_name:,
        timestamp:,
        algorithm: "hmac-sha256"
      )
    end
  end
end
