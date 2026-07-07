module Vitable
  WebhookDeliveryDto = Data.define(
    :id,
    :subscription_id,
    :webhook_event_id,
    :status,
    :created_at,
    :started_at,
    :delivered_at,
    :failed_at,
    :failure_reason
  ) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys

      new(
        id: attributes.fetch("id"),
        subscription_id: attributes.fetch("subscription_id", nil),
        webhook_event_id: attributes.fetch("webhook_event_id", nil),
        status: attributes.fetch("status", "Unknown"),
        created_at: parse_time(attributes.fetch("created_at", nil)),
        started_at: parse_time(attributes.fetch("started_at", nil)),
        delivered_at: parse_time(attributes.fetch("delivered_at", nil)),
        failed_at: parse_time(attributes.fetch("failed_at", nil)),
        failure_reason: attributes.fetch("failure_reason", nil)
      )
    end

    def status_key
      status.to_s.parameterize(separator: "_")
    end

    def self.parse_time(value)
      return if value.blank?
      return value if value.respond_to?(:strftime)

      Time.iso8601(value.to_s)
    end

    private_class_method :parse_time
  end
end
