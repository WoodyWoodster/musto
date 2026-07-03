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

      new(
        event_id: attrs.fetch(:event_id),
        organization_external_id: attrs.fetch(:organization_id),
        event_name: attrs.fetch(:event_name),
        resource_type: attrs.fetch(:resource_type),
        resource_id: attrs.fetch(:resource_id),
        occurred_at: Time.iso8601(attrs.fetch(:created_at)),
        payload: attrs
      )
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
