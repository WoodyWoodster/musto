module Vitable
  class ProcessWebhookCommand < ApplicationCommand
    def initialize(payload:, repository: IntegrationRepository.new)
      @payload = payload
      @repository = repository
    end

    def call
      dto = WebhookEventDto.from_payload(@payload)
      connection = @repository.connection_for_organization_external_id(dto.organization_external_id)
      event = @repository.persist_event(dto, connection)

      return success(record: event, value: "duplicate") if event.processed?

      if connection.blank?
        @repository.mark_unmatched_organization(event, dto.organization_external_id)
        return failure(record: event, errors: event.error_message)
      end

      unless connection.credentials_present?
        @repository.mark_needs_credentials(event, connection)
        return success(record: event, value: "queued_without_credentials")
      end

      fetch_dto = FetchResourceDto.from_event(connection:, event:)
      fetch_result = FetchResourceCommand.new(dto: fetch_dto, repository: @repository).call
      if fetch_result.success?
        @repository.mark_processed(event)
        success(record: event, value: fetch_result.value)
      else
        @repository.mark_failed(event, fetch_result.errors)
        failure(record: event, value: fetch_result.value, errors: fetch_result.errors)
      end
    rescue KeyError, ArgumentError => e
      failure(errors: "Invalid Vitable webhook payload: #{e.message}")
    end
  end
end
