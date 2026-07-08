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
    :failure_reason,
    :raw_payload
  ) do
    def self.from_hash(payload)
      attributes = payload.respond_to?(:to_h) ? payload.to_h.stringify_keys : {}

      new(
        id: attributes.fetch("id", nil),
        subscription_id: attributes.fetch("subscription_id", nil),
        webhook_event_id: attributes.fetch("webhook_event_id", nil),
        status: attributes.fetch("status", nil),
        created_at: parse_time(attributes.fetch("created_at", nil)),
        started_at: parse_time(attributes.fetch("started_at", nil)),
        delivered_at: parse_time(attributes.fetch("delivered_at", nil)),
        failed_at: parse_time(attributes.fetch("failed_at", nil)),
        failure_reason: attributes.fetch("failure_reason", nil),
        raw_payload: attributes
      )
    end

    def validate!(expected_webhook_event_id: nil, response_label: "Vitable webhook delivery")
      reference = id.presence || webhook_event_id.presence || "unknown delivery"
      raise ArgumentError, "#{response_label} #{reference} did not include a remote delivery ID" if id.blank?
      raise ArgumentError, "#{response_label} #{reference} did not include a remote webhook event ID" if webhook_event_id.blank?
      raise ArgumentError, "#{response_label} #{reference} did not include a webhook subscription ID" if subscription_id.blank?
      raise ArgumentError, "#{response_label} #{reference} did not include a delivery status" if status.blank?
      raise ArgumentError, "#{response_label} #{reference} did not include created_at" if created_at.blank?
      if expected_webhook_event_id.present? && webhook_event_id != expected_webhook_event_id
        raise ArgumentError, "#{response_label} #{reference} returned webhook event ID #{webhook_event_id}, expected #{expected_webhook_event_id}"
      end

      self
    end

    def status_key
      status.presence.to_s.parameterize(separator: "_")
    end

    def to_snapshot_hash
      raw_payload.merge(
        "id" => id,
        "subscription_id" => subscription_id,
        "webhook_event_id" => webhook_event_id,
        "status" => status,
        "created_at" => created_at&.iso8601,
        "started_at" => started_at&.iso8601,
        "delivered_at" => delivered_at&.iso8601,
        "failed_at" => failed_at&.iso8601,
        "failure_reason" => failure_reason
      )
    end

    def self.parse_time(value)
      return if value.blank?
      return value if value.respond_to?(:strftime)

      Time.iso8601(value.to_s)
    end

    private_class_method :parse_time
  end
end
