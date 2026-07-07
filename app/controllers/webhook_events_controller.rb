class WebhookEventsController < ApplicationController
  def show
    @webhook_event = Vitable::WebhookEventDetailQuery.new.call(params[:id])
  end

  def replay
    dto = Vitable::ReplayWebhookEventDto.from_params(params)
    result = Vitable::ReplayWebhookEventCommand.new(dto:).call

    redirect_to(
      result.record ? webhook_event_path(result.record) : integrations_path,
      notice: result.success? ? "Webhook replay queued." : result.errors.to_sentence
    )
  end

  def refresh_deliveries
    dto = Vitable::RefreshWebhookDeliveriesDto.from_params(params)
    result = Vitable::RefreshWebhookDeliveriesCommand.new(dto:).call

    redirect_to(
      webhook_event_path(params[:id]),
      notice: result.success? ? "Webhook deliveries refreshed." : result.errors.to_sentence
    )
  end
end
