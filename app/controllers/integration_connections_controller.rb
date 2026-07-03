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
end
