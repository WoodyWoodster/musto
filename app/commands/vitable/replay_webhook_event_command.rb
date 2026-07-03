module Vitable
  class ReplayWebhookEventCommand < ApplicationCommand
    def initialize(dto:, repository: IntegrationRepository.new)
      @dto = dto
      @repository = repository
    end

    def call
      event = @repository.find_webhook_event(@dto.webhook_event_id)
      payload = @repository.replay_payload(event)
      @repository.reset_event_for_replay(event)

      result = ProcessWebhookCommand.new(payload:, repository: @repository).call
      result.success? ? success(record: event.reload, value: result.value) : failure(record: event.reload, value: result.value, errors: result.errors)
    rescue ActiveRecord::RecordInvalid => e
      failure(record: e.record, errors: e.record.errors.full_messages)
    end
  end
end
