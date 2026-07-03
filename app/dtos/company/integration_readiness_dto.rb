module Company
  IntegrationReadinessDto = Data.define(
    :connection_id,
    :provider,
    :environment,
    :status,
    :api_key_reference,
    :webhook_secret_reference,
    :last_synced_at,
    :sync_run_count,
    :failed_sync_count
  ) do
    def self.from_record(record)
      return empty unless record

      new(
        connection_id: record.id,
        provider: record.provider,
        environment: record.environment,
        status: record.status,
        api_key_reference: record.api_key_reference,
        webhook_secret_reference: record.webhook_secret_reference,
        last_synced_at: record.last_synced_at,
        sync_run_count: record.sync_runs.size,
        failed_sync_count: record.sync_runs.count { |sync_run| sync_run.status == "failed" }
      )
    end

    def connected?
      status == "active" || status == "connected"
    end

    def missing_credentials?
      status == "needs_credentials"
    end

    def self.empty
      new(
        connection_id: nil,
        provider: "vitable",
        environment: "production",
        status: "not_configured",
        api_key_reference: "VITABLE_CONNECT_API_KEY",
        webhook_secret_reference: "VITABLE_WEBHOOK_SECRET",
        last_synced_at: nil,
        sync_run_count: 0,
        failed_sync_count: 0
      )
    end

    private_class_method :empty
  end
end
