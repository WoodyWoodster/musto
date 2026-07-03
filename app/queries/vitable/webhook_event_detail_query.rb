module Vitable
  class WebhookEventDetailQuery
    def initialize(repository: IntegrationRepository.new)
      @repository = repository
    end

    def call(id)
      event = @repository.find_webhook_event(id)
      WebhookEventDetailDto.from_record(
        event,
        sync_runs: @repository.related_sync_runs(event),
        request_logs: @repository.related_request_logs(event)
      )
    end
  end
end
