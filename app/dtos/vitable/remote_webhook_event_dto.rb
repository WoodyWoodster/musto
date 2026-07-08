module Vitable
  RemoteWebhookEventDto = Data.define(
    :event_id,
    :organization_id,
    :event_name,
    :resource_type,
    :resource_id,
    :occurred_at,
    :raw_payload
  ) do
    def self.from_remote_event(remote_event)
      attributes = event_attributes(remote_event.to_h.stringify_keys)
      event_id = attributes["event_id"].presence || attributes["id"].presence
      occurred_at = parse_time(attributes["created_at"].presence || attributes["occurred_at"].presence)
      organization_id = attributes["organization_id"].presence || attributes["organization_external_id"].presence

      return if [ event_id, organization_id, attributes["event_name"], attributes["resource_type"], attributes["resource_id"], occurred_at ].any?(&:blank?)

      new(
        event_id:,
        organization_id:,
        event_name: attributes.fetch("event_name"),
        resource_type: attributes.fetch("resource_type"),
        resource_id: attributes.fetch("resource_id"),
        occurred_at:,
        raw_payload: attributes
      )
    end

    def payload
      raw_payload.merge(
        "event_id" => event_id,
        "organization_id" => organization_id,
        "event_name" => event_name,
        "resource_type" => resource_type,
        "resource_id" => resource_id,
        "created_at" => occurred_at.iso8601
      )
    end

    def to_snapshot_hash
      payload
    end

    def to_event_attributes
      {
        organization_external_id: organization_id,
        event_name:,
        resource_type:,
        resource_id:,
        occurred_at:,
        payload:
      }
    end

    def self.remote_event_id(remote_event)
      attributes = remote_event.to_h.stringify_keys
      attributes["event_id"].presence ||
        attributes["id"].presence ||
        nested_event_id(attributes).presence ||
        "unknown"
    end

    def self.event_attributes(attributes)
      return attributes if attributes["event_id"].present? || attributes["id"].present?

      data = attributes["data"]
      return attributes unless data.respond_to?(:to_h)

      data_attributes = data.to_h.stringify_keys
      return attributes unless event_envelope?(data_attributes)

      attributes.merge(data_attributes)
    end

    def self.event_envelope?(attributes)
      (attributes["event_id"].present? || attributes["id"].present?) &&
        attributes["event_name"].present? &&
        attributes["resource_type"].present? &&
        attributes["resource_id"].present? &&
        (attributes["created_at"].present? || attributes["occurred_at"].present?)
    end

    def self.nested_event_id(attributes)
      data = attributes["data"]
      return unless data.respond_to?(:to_h)

      data_attributes = data.to_h.stringify_keys
      data_attributes["event_id"].presence || data_attributes["id"].presence
    end

    def self.parse_time(value)
      return value if value.respond_to?(:iso8601)
      return if value.blank?

      Time.iso8601(value.to_s)
    rescue ArgumentError
      nil
    end

    private_class_method :event_attributes, :event_envelope?, :nested_event_id, :parse_time
  end
end
