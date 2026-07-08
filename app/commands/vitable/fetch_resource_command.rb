module Vitable
  class FetchResourceCommand < ApplicationCommand
    def initialize(dto:, repository: IntegrationRepository.new, gateway_class: ClientGateway, reconcile: true)
      @dto = dto
      @repository = repository
      @gateway_class = gateway_class
      @reconcile = reconcile
    end

    def call
      connection = @repository.find_connection(@dto.connection_id)
      sync_run = @repository.create_sync_run(
        connection:,
        resource_type: @dto.resource_type,
        resource_id: @dto.resource_id
      )

      response = @gateway_class.new(connection).fetch_resource(@dto.resource_type, @dto.resource_id)
      reconciliation = reconcile_resource(connection, response)
      @repository.succeed_sync_run(sync_run, response)
      @repository.annotate_sync_run_reconciliation(sync_run, reconciliation) if reconciliation
      success(record: sync_run, value: response)
    rescue VitableConnect::Errors::APIError => e
      @repository.fail_sync_run(sync_run, e)
      failure(record: sync_run, errors: "#{e.class}: #{e.message}")
    rescue ArgumentError => e
      @repository.fail_sync_run(sync_run, e)
      failure(record: sync_run, errors: e.message)
    end

    private

    def reconcile_resource(connection, response)
      return unless @reconcile

      @repository.reconcile_fetched_resource(
        connection:,
        resource_type: @dto.resource_type,
        resource_id: @dto.resource_id,
        response:
      )
    end
  end
end
