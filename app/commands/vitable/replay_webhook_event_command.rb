module Vitable
  class ReplayWebhookEventCommand < ApplicationCommand
    def initialize(dto:, repository: IntegrationRepository.new, gateway_class: ClientGateway)
      @dto = dto
      @repository = repository
      @gateway_class = gateway_class
    end

    def call
      event = @repository.find_webhook_event(@dto.webhook_event_id)
      return failure(record: event, errors: "No Vitable connection is associated with this webhook event") unless event.integration_connection

      sync_run = @repository.create_webhook_replay_run(event:, requested_by: @dto.requested_by)
      payload = @repository.replay_payload(event)
      @repository.reset_event_for_replay(event)

      result = ProcessWebhookCommand.new(payload:, repository: @repository, gateway_class: @gateway_class).call
      event.reload

      if result.success?
        @repository.finish_webhook_replay_run(sync_run, event:, result:)
        success(record: event, value: result.value)
      else
        @repository.fail_webhook_replay_run(sync_run, event:, errors: result.errors)
        failure(record: event, value: result.value, errors: result.errors)
      end
    rescue ActiveRecord::RecordInvalid => e
      failure(record: e.record, errors: e.record.errors.full_messages)
    end
  end
end
