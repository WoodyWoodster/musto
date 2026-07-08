module Vitable
  class SimulateWebhookEventCommand < ApplicationCommand
    REQUIRED_FIELDS = {
      event_name: "Event name",
      resource_type: "Resource type",
      resource_id: "Resource ID"
    }.freeze

    def initialize(dto:, repository: IntegrationRepository.new)
      @dto = dto
      @repository = repository
    end

    def call
      connection = @repository.find_connection_with_organization(@dto.connection_id)
      missing = missing_fields
      return failure(record: connection, errors: "#{missing.to_sentence} required") if missing.any?

      result = ProcessWebhookCommand.new(
        payload: @repository.webhook_simulator_payload(connection, @dto),
        repository: @repository
      ).call

      result.success? ? success(record: result.record, value: result.value) : failure(record: result.record || connection, value: result.value, errors: result.errors)
    end

    private

    def missing_fields
      REQUIRED_FIELDS.filter_map do |field, label|
        label if @dto.public_send(field).blank?
      end
    end
  end
end
