module Vitable
  WebhookSignatureVerificationDto = Data.define(:status, :detail, :connection_id, :header_name, :timestamp, :algorithm) do
    ACCEPTED_STATUSES = %w[verified not_configured unmatched_organization skipped].freeze

    def self.skipped(detail: "Signature verification was not run.")
      new(status: "skipped", detail:, connection_id: nil, header_name: nil, timestamp: nil, algorithm: "hmac-sha512")
    end

    def accepted?
      status.in?(ACCEPTED_STATUSES)
    end

    def rejected?
      !accepted?
    end

    def to_metadata
      {
        "status" => status,
        "detail" => detail,
        "connection_id" => connection_id,
        "header_name" => header_name,
        "timestamp" => timestamp,
        "algorithm" => algorithm
      }.compact
    end
  end
end
