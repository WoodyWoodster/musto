module Vitable
  WebhookEventDto = Data.define(
    :event_id,
    :organization_external_id,
    :event_name,
    :resource_type,
    :resource_id,
    :occurred_at,
    :payload
  ) do
    def self.from_payload(payload)
      attrs = ApplicationDto.coerce_hash(payload).deep_symbolize_keys
      event_id = attrs[:event_id].presence || attrs[:id].presence
      raise KeyError, "key not found: :event_id" if event_id.blank?

      timestamp = attrs[:created_at].presence || attrs[:occurred_at].presence
      occurred_at = parse_time!(timestamp)
      organization_external_id = organization_external_id_from(attrs)

      new(
        event_id:,
        organization_external_id:,
        event_name: required_attr(attrs, :event_name),
        resource_type: required_attr(attrs, :resource_type),
        resource_id: required_attr(attrs, :resource_id),
        occurred_at:,
        payload: attrs.merge(event_id:, organization_id: organization_external_id, created_at: occurred_at.iso8601)
      )
    end

    def self.organization_external_id_from(attrs)
      attrs[:organization_id].presence ||
        attrs[:organization_external_id].presence ||
        required_attr(attrs, :organization_id)
    end

    def self.required_attr(attrs, key)
      value = attrs[key].presence
      raise KeyError, "key not found: #{key.inspect}" if value.blank?

      value
    end

    def self.parse_time!(value)
      raise KeyError, "key not found: :created_at" if value.blank?

      Time.iso8601(value.to_s)
    rescue ArgumentError
      raise ArgumentError, "created_at could not be parsed as ISO 8601"
    end

    def to_event_attributes
      {
        event_id:,
        organization_external_id:,
        event_name:,
        resource_type:,
        resource_id:,
        occurred_at:,
        payload:
      }
    end
  end
end
