module Vitable
  class FetchResourceCommand < ApplicationCommand
    def initialize(connection:, resource_type:, resource_id:)
      @connection = connection
      @resource_type = resource_type
      @resource_id = resource_id
    end

    def call
      sync_run = @connection.sync_runs.create!(
        resource_type: @resource_type,
        operation: "fetch",
        status: "running",
        started_at: Time.current,
        stats: { resource_id: @resource_id }
      )

      response = ClientGateway.new(@connection).fetch_resource(@resource_type, @resource_id)
      sync_run.update!(status: "succeeded", completed_at: Time.current, stats: sync_run.stats.merge(response_class: response.class.name))
      success(record: sync_run, value: response)
    rescue VitableConnect::Errors::APIError => e
      sync_run&.update!(status: "failed", completed_at: Time.current, error_message: e.message)
      failure(record: sync_run, errors: "#{e.class}: #{e.message}")
    end
  end
end
