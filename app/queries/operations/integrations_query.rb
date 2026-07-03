module Operations
  class IntegrationsQuery
    def initialize(repository: Vitable::IntegrationRepository.new)
      @repository = repository
    end

    def call
      {
        connections: @repository.connections.map { |connection| IntegrationConnectionDto.from_record(connection) },
        webhooks: @repository.webhooks.map { |event| IntegrationWebhookEventDto.from_record(event) },
        sync_runs: @repository.sync_runs.map { |sync_run| SyncRunDto.from_record(sync_run) },
        request_logs: @repository.request_logs.map { |request_log| ApiRequestLogDto.from_record(request_log) }
      }
    end
  end
end
