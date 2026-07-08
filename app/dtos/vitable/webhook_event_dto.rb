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
      raw_attrs = ApplicationDto.coerce_hash(payload).deep_symbolize_keys
      attrs = event_attributes(raw_attrs)
      event_id = attrs[:event_id].presence || attrs[:id].presence
      raise KeyError, "key not found: :event_id" if event_id.blank?

      timestamp = attrs[:created_at].presence || attrs[:occurred_at].presence
      occurred_at = parse_time!(timestamp)
      organization_external_id = organization_external_id_from(attrs)
      event_name = required_attr(attrs, :event_name)
      resource_type = required_attr(attrs, :resource_type)
      resource_id = required_attr(attrs, :resource_id)

      new(
        event_id:,
        organization_external_id:,
        event_name:,
        resource_type:,
        resource_id:,
        occurred_at:,
        payload: raw_attrs.merge(
          event_id:,
          organization_id: organization_external_id,
          event_name:,
          resource_type:,
          resource_id:,
          created_at: occurred_at.iso8601
        )
      )
    end

    def self.event_attributes(attrs)
      return attrs if attrs[:event_id].present? || attrs[:id].present?

      data = attrs[:data]
      return attrs unless data.respond_to?(:to_h)

      data_attrs = data.to_h.deep_symbolize_keys
      return attrs unless event_envelope?(data_attrs)

      attrs.merge(data_attrs)
    end

    def self.event_envelope?(attrs)
      (attrs[:event_id].present? || attrs[:id].present?) &&
        attrs[:event_name].present? &&
        attrs[:resource_type].present? &&
        attrs[:resource_id].present? &&
        (attrs[:created_at].present? || attrs[:occurred_at].present?)
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

    private_class_method :event_attributes, :event_envelope?
  end
end
