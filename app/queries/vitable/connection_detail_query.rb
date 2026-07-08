module Vitable
  class ConnectionDetailQuery
    def initialize(repository: IntegrationRepository.new)
      @repository = repository
    end

    def call(id)
      connection = @repository.find_connection_with_organization(id)
      ConnectionDetailDto.from_record(
        connection,
        webhook_events: @repository.connection_webhook_events(connection),
        sync_runs: @repository.connection_sync_runs(connection),
        request_logs: @repository.connection_request_logs(connection),
        simulator_resource_ids: @repository.webhook_simulator_resource_ids(connection)
      )
    end
  end
end
