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
    EVENT_ENVELOPE_KEYS = %w[data webhook_event webhookEvent event object resource].freeze
    EVENT_ID_ENVELOPE_KEYS = %w[data webhook_event webhookEvent event object].freeze

    def self.from_remote_event(remote_event)
      attributes = event_attributes(remote_event.to_h.deep_stringify_keys)
      event_id = event_id_from(attributes)
      occurred_at = parse_time(timestamp_from(attributes))
      organization_id = organization_id_from(attributes)
      event_name = event_name_from(attributes)
      resource_type = resource_type_from(attributes)
      resource_id = resource_id_from(attributes)

      return if [ event_id, organization_id, event_name, resource_type, resource_id, occurred_at ].any?(&:blank?)

      new(
        event_id:,
        organization_id:,
        event_name:,
        resource_type:,
        resource_id:,
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
      attributes = remote_event.to_h.deep_stringify_keys
      event_id_from(attributes).presence ||
        nested_event_id(attributes).presence ||
        "unknown"
    end

    def self.event_attributes(attributes)
      return attributes if event_envelope?(attributes)

      nested_attributes = nested_event_attributes(attributes)
      return attributes unless nested_attributes.present?

      attributes.merge(nested_attributes)
    end

    def self.event_envelope?(attributes)
      event_id_from(attributes).present? &&
        event_name_from(attributes).present? &&
        resource_type_from(attributes).present? &&
        resource_id_from(attributes).present? &&
        timestamp_from(attributes).present?
    end

    def self.nested_event_attributes(attributes)
      EVENT_ENVELOPE_KEYS.each do |key|
        value = attributes[key]
        next if value.blank? || !value.respond_to?(:to_h)

        child_attributes = value.to_h.deep_stringify_keys
        return child_attributes if event_envelope?(child_attributes)

        nested_attributes = nested_event_attributes(child_attributes)
        return nested_attributes if nested_attributes.present?
      end

      nil
    end

    def self.event_id_from(attributes)
      attributes["event_id"].presence || attributes["id"].presence || attributes["webhook_event_id"].presence
    end

    def self.organization_id_from(attributes)
      attributes["organization_id"].presence ||
        attributes["organization_external_id"].presence ||
        organization_value_from(attributes)&.fetch("id", nil).presence ||
        organization_value_from(attributes)&.fetch("external_id", nil).presence
    end

    def self.organization_value_from(attributes)
      organization = attributes["organization"]
      return if organization.blank? || !organization.respond_to?(:to_h)

      organization.to_h.deep_stringify_keys
    end

    def self.event_name_from(attributes)
      attributes["event_name"].presence ||
        attributes["event_type"].presence ||
        dotted_value(attributes["type"])
    end

    def self.resource_type_from(attributes)
      attributes["resource_type"].presence || resource_value_from(attributes)&.fetch("type", nil).presence
    end

    def self.resource_id_from(attributes)
      attributes["resource_id"].presence || resource_value_from(attributes)&.fetch("id", nil).presence
    end

    def self.resource_value_from(attributes)
      resource = attributes["resource"]
      return if resource.blank? || !resource.respond_to?(:to_h)

      resource.to_h.deep_stringify_keys
    end

    def self.timestamp_from(attributes)
      attributes["created_at"].presence ||
        attributes["occurred_at"].presence ||
        attributes["timestamp"].presence
    end

    def self.dotted_value(value)
      return if value.blank?

      candidate = value.to_s
      return candidate if candidate.include?(".")

      nil
    end

    def self.nested_event_id(attributes)
      EVENT_ID_ENVELOPE_KEYS.each do |key|
        value = attributes[key]
        next if value.blank? || !value.respond_to?(:to_h)

        child_attributes = value.to_h.deep_stringify_keys
        event_id = event_id_from(child_attributes).presence || nested_event_id(child_attributes).presence
        return event_id if event_id.present?
      end

      nil
    end

    def self.parse_time(value)
      return value if value.respond_to?(:iso8601)
      return if value.blank?

      Time.iso8601(value.to_s)
    rescue ArgumentError
      nil
    end

    private_class_method(
      :dotted_value,
      :event_attributes,
      :event_envelope?,
      :event_id_from,
      :event_name_from,
      :nested_event_attributes,
      :nested_event_id,
      :organization_id_from,
      :organization_value_from,
      :parse_time,
      :resource_id_from,
      :resource_type_from,
      :resource_value_from,
      :timestamp_from
    )
  end
end
