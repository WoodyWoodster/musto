module Vitable
  class VerifyConnectionCommand < ApplicationCommand
    def initialize(dto:, repository: IntegrationRepository.new, gateway_class: ClientGateway)
      @dto = dto
      @repository = repository
      @gateway_class = gateway_class
    end

    def call
      response = nil
      connection = @repository.find_connection(@dto.connection_id)

      unless connection.credentials_present?
        @repository.mark_connection_needs_credentials(connection)
        return failure(record: connection, errors: "#{connection.api_key_reference} is not configured")
      end

      response = @gateway_class.new(connection).issue_access_token
      RemoteAccessTokenResponseDto.from_response(serialize_response(response)).validate!

      @repository.mark_connection_active(connection)
      success(record: connection, value: response)
    rescue VitableConnect::Errors::APIError => e
      @repository.mark_connection_failed(connection, e)
      failure(record: connection, errors: PayloadRedactor.error_with_class(e))
    rescue ArgumentError => e
      @repository.mark_connection_failed(connection, e, response:)
      failure(record: connection, errors: PayloadRedactor.error_message(e))
    end

    private

    def serialize_response(response)
      return {} if response.blank?
      return response.deep_to_h.deep_stringify_keys if response.respond_to?(:deep_to_h)
      return response.to_h.deep_stringify_keys if response.respond_to?(:to_h)

      { "value" => response.to_s }
    end
  end
end
