module Vitable
  ReplayWebhookEventDto = Data.define(:webhook_event_id) do
    def self.from_params(params)
      new(webhook_event_id: ApplicationDto.id_from(params))
    end
  end
end
