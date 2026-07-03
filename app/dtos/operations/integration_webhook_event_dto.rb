module Operations
  IntegrationWebhookEventDto = Data.define(
    :id,
    :event_id,
    :event_name,
    :resource_type,
    :resource_id,
    :organization_external_id,
    :status,
    :created_at
  ) do
    def self.from_record(record)
      new(
        id: record.id,
        event_id: record.event_id,
        event_name: record.event_name,
        resource_type: record.resource_type,
        resource_id: record.resource_id,
        organization_external_id: record.organization_external_id,
        status: record.status,
        created_at: record.created_at
      )
    end
  end
end
