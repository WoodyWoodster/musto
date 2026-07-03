module Vitable
  class VerifyConnectionCommand < ApplicationCommand
    def initialize(dto:, repository: IntegrationRepository.new, gateway_class: ClientGateway)
      @dto = dto
      @repository = repository
      @gateway_class = gateway_class
    end

    def call
      connection = @repository.find_connection(@dto.connection_id)

      unless connection.credentials_present?
        @repository.mark_connection_needs_credentials(connection)
        return failure(record: connection, errors: "#{connection.api_key_reference} is not configured")
      end

      response = @gateway_class.new(connection).issue_access_token
      @repository.mark_connection_active(connection)
      success(record: connection, value: response)
    rescue VitableConnect::Errors::APIError => e
      @repository.mark_connection_failed(connection, e)
      failure(record: connection, errors: "#{e.class}: #{e.message}")
    end
  end
end
