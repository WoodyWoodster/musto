module Vitable
  ReplayWebhookEventDto = Data.define(:webhook_event_id, :requested_by) do
    def self.from_params(params)
      attributes = ApplicationDto.coerce_hash(params)

      new(
        webhook_event_id: ApplicationDto.id_from(params),
        requested_by: attributes.fetch("requested_by", "operations_console")
      )
    end
  end
end
