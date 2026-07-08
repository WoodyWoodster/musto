require "securerandom"

module Vitable
  SimulateWebhookEventDto = Data.define(
    :connection_id,
    :event_id,
    :event_name,
    :resource_type,
    :resource_id,
    :occurred_at
  ) do
    def self.from_params(params)
      attrs = ApplicationDto.coerce_hash(params).deep_symbolize_keys

      new(
        connection_id: ApplicationDto.id_from(attrs),
        event_id: attrs[:event_id].presence || "wevt_test_#{SecureRandom.hex(8)}",
        event_name: attrs[:event_name].to_s,
        resource_type: attrs[:resource_type].to_s,
        resource_id: attrs[:resource_id].to_s,
        occurred_at: attrs[:occurred_at].present? ? Time.iso8601(attrs[:occurred_at]) : Time.current
      )
    end

    def to_payload(organization_external_id)
      {
        event_id:,
        organization_id: organization_external_id,
        event_name:,
        resource_type:,
        resource_id:,
        created_at: occurred_at.iso8601
      }
    end
  end
end
