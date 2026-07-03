module Operations
  IntegrationConnectionDto = Data.define(
    :id,
    :organization_name,
    :provider,
    :environment,
    :status,
    :api_key_reference,
    :webhook_secret_reference
  ) do
    def self.from_record(record)
      new(
        id: record.id,
        organization_name: record.organization.name,
        provider: record.provider,
        environment: record.environment,
        status: record.status,
        api_key_reference: record.api_key_reference,
        webhook_secret_reference: record.webhook_secret_reference
      )
    end
  end
end
