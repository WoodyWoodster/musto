module Vitable
  class ProcessWebhookCommand < ApplicationCommand
    def initialize(payload:, repository: IntegrationRepository.new, signature_verification: WebhookSignatureVerificationDto.skipped, gateway_class: ClientGateway)
      @payload = payload
      @repository = repository
      @signature_verification = signature_verification
      @gateway_class = gateway_class
    end

    def call
      event = nil
      dto = WebhookEventDto.from_payload(@payload)
      connection = @repository.connection_for_organization_external_id(dto.organization_external_id)
      event = @repository.persist_event(dto, connection, signature_verification: @signature_verification)

      return success(record: event, value: "duplicate") if event.processed?

      if connection.blank?
        @repository.mark_unmatched_organization(event, dto.organization_external_id)
        return failure(record: event, errors: event.error_message)
      end

      unless connection.credentials_present?
        @repository.mark_needs_credentials(event, connection)
        return success(record: event, value: "queued_without_credentials")
      end

      unless retrievable_resource_type?(event.resource_type)
        reconciliation = @repository.snapshot_only_webhook_reconciliation(event)
        @repository.mark_processed(event, reconciliation:)
        return success(record: event, value: "snapshot_only")
      end

      fetch_dto = FetchResourceDto.from_event(connection:, event:)
      fetch_result = FetchResourceCommand.new(dto: fetch_dto, repository: @repository, gateway_class: @gateway_class, reconcile: false).call
      if fetch_result.success?
        reconciliation = @repository.reconcile_webhook_resource(event, fetch_result.value)
        @repository.annotate_sync_run_reconciliation(fetch_result.record, reconciliation)
        @repository.mark_processed(event, response: fetch_result.value, reconciliation:)
        success(record: event, value: fetch_result.value)
      else
        @repository.mark_failed(event, fetch_result.errors)
        failure(record: event, value: fetch_result.value, errors: fetch_result.errors)
      end
    rescue KeyError, ArgumentError => e
      if event
        @repository.mark_failed(event, e.message)
        return failure(record: event, errors: e.message)
      end

      failure(errors: "Invalid Vitable webhook payload: #{e.message}")
    end

    private

    def retrievable_resource_type?(resource_type)
      return true unless @gateway_class.respond_to?(:retrievable_resource_type?)

      @gateway_class.retrievable_resource_type?(resource_type)
    end
  end
end
