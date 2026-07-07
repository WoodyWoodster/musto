class IntegrationConnectionsController < ApplicationController
  def show
    @connection = Vitable::ConnectionDetailQuery.new.call(params[:id])
  end

  def verify_credentials
    dto = Vitable::VerifyConnectionDto.from_params(params)
    result = Vitable::VerifyConnectionCommand.new(dto:).call

    redirect_to(
      result.record ? integration_connection_path(result.record) : integrations_path,
      notice: result.success? ? "Vitable credentials verified." : result.errors.to_sentence
    )
  end

  def refresh_api_snapshot
    dto = Vitable::RefreshApiSnapshotDto.from_params(params)
    result = Vitable::RefreshApiSnapshotCommand.new(dto:).call

    redirect_to(
      result.record ? integration_connection_path(dto.connection_id) : integrations_path,
      notice: result.success? ? "Vitable API snapshot refreshed." : result.errors.to_sentence
    )
  end

  def simulate_webhook
    dto = Vitable::SimulateWebhookEventDto.from_params(params)
    result = Vitable::SimulateWebhookEventCommand.new(dto:).call

    redirect_to(
      result.record ? webhook_event_path(result.record) : integration_connection_path(dto.connection_id),
      notice: result.success? ? "Sandbox webhook processed." : result.errors.to_sentence
    )
  end
end
