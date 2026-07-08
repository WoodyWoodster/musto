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
      event_id = event_id_from(attrs)
      raise KeyError, "key not found: :event_id" if event_id.blank?

      occurred_at = parse_time!(timestamp_from(attrs))
      organization_external_id = organization_external_id_from(attrs)
      event_name = required_event_name(attrs)
      resource_type = required_resource_type(attrs)
      resource_id = required_resource_id(attrs)

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
      return attrs if event_envelope?(attrs)

      nested_attrs = nested_event_attributes(attrs)
      return attrs unless nested_attrs.present?

      attrs.merge(nested_attrs)
    end

    def self.event_envelope?(attrs)
      event_id_from(attrs).present? &&
        event_name_from(attrs).present? &&
        resource_type_from(attrs).present? &&
        resource_id_from(attrs).present? &&
        timestamp_from(attrs).present?
    end

    def self.nested_event_attributes(attrs)
      event_envelope_keys.each do |key|
        value = attrs[key]
        next if value.blank? || !value.respond_to?(:to_h)

        child_attrs = value.to_h.deep_symbolize_keys
        return child_attrs if event_envelope?(child_attrs)

        nested_attrs = nested_event_attributes(child_attrs)
        return nested_attrs if nested_attrs.present?
      end

      nil
    end

    def self.event_envelope_keys
      %i[data webhook_event webhookEvent event object resource]
    end

    def self.event_id_from(attrs)
      attrs[:event_id].presence || attrs[:id].presence || attrs[:webhook_event_id].presence
    end

    def self.organization_external_id_from(attrs)
      attrs[:organization_id].presence ||
        attrs[:organization_external_id].presence ||
        organization_value_from(attrs)&.fetch(:id, nil).presence ||
        organization_value_from(attrs)&.fetch(:external_id, nil).presence ||
        required_attr(attrs, :organization_id)
    end

    def self.organization_value_from(attrs)
      organization = attrs[:organization]
      return if organization.blank? || !organization.respond_to?(:to_h)

      organization.to_h.deep_symbolize_keys
    end

    def self.event_name_from(attrs)
      attrs[:event_name].presence ||
        attrs[:event_type].presence ||
        dotted_value(attrs[:type])
    end

    def self.resource_type_from(attrs)
      attrs[:resource_type].presence || resource_value_from(attrs)&.fetch(:type, nil).presence
    end

    def self.resource_id_from(attrs)
      attrs[:resource_id].presence || resource_value_from(attrs)&.fetch(:id, nil).presence
    end

    def self.resource_value_from(attrs)
      resource = attrs[:resource]
      return if resource.blank? || !resource.respond_to?(:to_h)

      resource.to_h.deep_symbolize_keys
    end

    def self.timestamp_from(attrs)
      attrs[:created_at].presence ||
        attrs[:occurred_at].presence ||
        attrs[:timestamp].presence
    end

    def self.dotted_value(value)
      return if value.blank?

      candidate = value.to_s
      return candidate if candidate.include?(".")

      nil
    end

    def self.required_event_name(attrs)
      value = event_name_from(attrs)
      raise KeyError, "key not found: :event_name" if value.blank?

      value
    end

    def self.required_resource_type(attrs)
      value = resource_type_from(attrs)
      raise KeyError, "key not found: :resource_type" if value.blank?

      value
    end

    def self.required_resource_id(attrs)
      value = resource_id_from(attrs)
      raise KeyError, "key not found: :resource_id" if value.blank?

      value
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

    private_class_method(
      :dotted_value,
      :event_attributes,
      :event_envelope?,
      :event_envelope_keys,
      :event_id_from,
      :event_name_from,
      :nested_event_attributes,
      :organization_external_id_from,
      :organization_value_from,
      :parse_time!,
      :required_attr,
      :required_event_name,
      :required_resource_id,
      :required_resource_type,
      :resource_id_from,
      :resource_type_from,
      :resource_value_from,
      :timestamp_from
    )
  end
end
