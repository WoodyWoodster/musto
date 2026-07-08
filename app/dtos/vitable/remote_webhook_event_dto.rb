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
      attributes = remote_event.to_h.stringify_keys
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
      attributes["event_id"].presence || attributes["id"].presence || "unknown"
    end

    def self.parse_time(value)
      return value if value.respond_to?(:iso8601)
      return if value.blank?

      Time.iso8601(value.to_s)
    rescue ArgumentError
      nil
    end

    private_class_method :parse_time
  end
end
