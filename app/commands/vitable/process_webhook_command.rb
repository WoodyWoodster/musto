module Vitable
  class ProcessWebhookCommand < ApplicationCommand
    def initialize(payload:)
      @payload = payload
    end

    def call
      dto = WebhookEventDto.from_payload(@payload)
      connection = resolve_connection(dto)
      event = persist_event(dto, connection)

      return success(record: event, value: "duplicate") if event.processed?

      if connection.blank?
        event.update!(status: "unmatched_organization", error_message: "No Vitable connection matched #{dto.organization_external_id}")
        return failure(record: event, errors: event.error_message)
      end

      unless connection.credentials_present?
        event.update!(status: "needs_credentials", error_message: "#{connection.api_key_reference} is not configured")
        return success(record: event, value: "queued_without_credentials")
      end

      fetch_result = FetchResourceCommand.new(connection:, resource_type: dto.resource_type, resource_id: dto.resource_id).call
      if fetch_result.success?
        event.update!(status: "processed", processed_at: Time.current, error_message: nil)
        success(record: event, value: fetch_result.value)
      else
        event.update!(status: "failed", error_message: fetch_result.errors.join(", "))
        failure(record: event, value: fetch_result.value, errors: fetch_result.errors)
      end
    rescue KeyError, ArgumentError => e
      failure(errors: "Invalid Vitable webhook payload: #{e.message}")
    end

    private

    def resolve_connection(dto)
      organization = Organization.find_by(external_id: dto.organization_external_id)
      organization&.integration_connections&.vitable&.find_by(environment: "production") ||
        organization&.integration_connections&.vitable&.first
    end

    def persist_event(dto, connection)
      WebhookEvent.find_by(event_id: dto.event_id) || WebhookEvent.create!(event_id: dto.event_id) do |event|
        event.assign_attributes(dto.to_event_attributes)
        event.integration_connection = connection
        event.status = "received"
      end
    end
  end
end
