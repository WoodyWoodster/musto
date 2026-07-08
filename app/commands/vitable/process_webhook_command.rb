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
        reconciliation = @repository.payload_only_webhook_reconciliation(
          event,
          known_payload_only_resource_type: payload_only_webhook_resource_type?(event.resource_type),
          known_webhook_resource_type: webhook_resource_type?(event.resource_type)
        )
        @repository.mark_processed(event, reconciliation:)
        return success(record: event, value: reconciliation.status == "matched" ? "payload_only" : "snapshot_only")
      end

      fetch_result = FetchResourceCommand.new(
        dto: FetchResourceDto.from_event(connection:, event:),
        repository: @repository,
        gateway_class: @gateway_class,
        reconcile: false
      ).call
      if fetch_result.success?
        reconciliation = reconcile_webhook_resource(event, fetch_result)
        @repository.annotate_sync_run_reconciliation(fetch_result.record, reconciliation)
        @repository.mark_processed(event, response: fetch_result.value, reconciliation:)
        success(record: event, value: fetch_result.value)
      else
        @repository.mark_failed(event, fetch_result.errors)
        failure(record: event, value: fetch_result.value, errors: fetch_result.errors)
      end
    rescue KeyError, ArgumentError => e
      if event
        @repository.mark_failed(event, PayloadRedactor.error_message(e))
        return failure(record: event, errors: PayloadRedactor.error_message(e))
      end

      failure(errors: "Invalid Vitable webhook payload: #{PayloadRedactor.error_message(e)}")
    end

    private

    def retrievable_resource_type?(resource_type)
      return true unless @gateway_class.respond_to?(:retrievable_resource_type?)

      @gateway_class.retrievable_resource_type?(resource_type)
    end

    def webhook_resource_type?(resource_type)
      return false unless @gateway_class.respond_to?(:webhook_resource_type?)

      @gateway_class.webhook_resource_type?(resource_type)
    end

    def payload_only_webhook_resource_type?(resource_type)
      return false unless @gateway_class.respond_to?(:payload_only_webhook_resource_type?)

      @gateway_class.payload_only_webhook_resource_type?(resource_type)
    end

    def reconcile_webhook_resource(event, fetch_result)
      @repository.reconcile_webhook_resource(event, fetch_result.value)
    rescue ArgumentError => e
      @repository.fail_sync_run_after_response(fetch_result.record, fetch_result.value, e)
      raise
    end
  end
end
