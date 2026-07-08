module Vitable
  class RefreshWebhookDeliveriesCommand < ApplicationCommand
    def initialize(dto:, repository: IntegrationRepository.new, gateway_class: ClientGateway)
      @dto = dto
      @repository = repository
      @gateway_class = gateway_class
    end

    def call
      event = @repository.find_webhook_event(@dto.webhook_event_id)
      return failure(record: event, errors: "No Vitable connection is associated with this webhook event") unless event.integration_connection

      sync_run = @repository.create_webhook_delivery_run(event:, requested_by: @dto.requested_by)

      unless event.integration_connection.credentials_present?
        sync_run = @repository.mark_webhook_delivery_needs_credentials(sync_run)
        return failure(record: sync_run, errors: sync_run.error_message)
      end

      response = @gateway_class.new(event.integration_connection).list_webhook_event_deliveries(event.event_id)
      sync_run = @repository.succeed_webhook_delivery_run(event, sync_run, response)
      success(record: sync_run, value: response)
    rescue VitableConnect::Errors::APIError => e
      @repository.fail_webhook_delivery_run(sync_run, e)
      failure(record: sync_run, errors: "#{e.class}: #{e.message}")
    rescue ArgumentError => e
      @repository.fail_webhook_delivery_run(sync_run, e)
      failure(record: sync_run, errors: e.message)
    rescue ActiveRecord::RecordInvalid => e
      failure(record: e.record, errors: e.record.errors.full_messages)
    end
  end
end
