module Vitable
  WebhookEventDetailDto = Data.define(
    :id,
    :event_id,
    :event_name,
    :resource_type,
    :resource_id,
    :organization_external_id,
    :status,
    :occurred_at,
    :received_at,
    :processed_at,
    :error_message,
    :payload,
    :connection,
    :sync_runs,
    :request_logs,
    :preflight_checks,
    :timeline
  ) do
    def self.from_record(record, sync_runs:, request_logs:)
      new(
        id: record.id,
        event_id: record.event_id,
        event_name: record.event_name,
        resource_type: record.resource_type,
        resource_id: record.resource_id,
        organization_external_id: record.organization_external_id,
        status: record.status,
        occurred_at: record.occurred_at,
        received_at: record.created_at,
        processed_at: record.processed_at,
        error_message: record.error_message,
        payload: record.payload || {},
        connection: record.integration_connection && Operations::IntegrationConnectionDto.from_record(record.integration_connection),
        sync_runs: sync_runs.map { |sync| Operations::SyncRunDto.from_record(sync) },
        request_logs: request_logs.map { |log| Operations::ApiRequestLogDto.from_record(log) },
        preflight_checks: preflight_checks(record),
        timeline: timeline(record, sync_runs, request_logs)
      )
    end

    def replayable?
      true
    end

    def processed?
      processed_at.present?
    end

    def self.preflight_checks(record)
      connection = record.integration_connection

      [
        WebhookPreflightCheckDto.new(
          label: "Event idempotency",
          status: "ready",
          detail: "#{record.event_id} is stored once and replayed in place"
        ),
        WebhookPreflightCheckDto.new(
          label: "Organization routing",
          status: connection.present? ? "ready" : "needs_review",
          detail: connection.present? ? "#{connection.organization.name} matched" : "No matching Vitable connection"
        ),
        WebhookPreflightCheckDto.new(
          label: "Credential readiness",
          status: connection&.credentials_present? ? "ready" : "needs_credentials",
          detail: connection&.credentials_present? ? "#{connection.api_key_reference} is configured" : "#{connection&.api_key_reference || "Vitable API key"} is not configured"
        ),
        WebhookPreflightCheckDto.new(
          label: "Processing state",
          status: record.processed? ? "processed" : record.status,
          detail: record.processed? ? "Processed #{record.processed_at.strftime('%b %-d, %I:%M %p')}" : "Current status is #{record.status.humanize.downcase}"
        )
      ]
    end

    def self.timeline(record, sync_runs, request_logs)
      [
        WebhookTimelineItemDto.new(
          type: "Webhook",
          title: record.event_name,
          subtitle: "#{record.resource_type} #{record.resource_id}",
          status: record.status,
          timestamp: record.created_at
        ),
        record.processed_at && WebhookTimelineItemDto.new(
          type: "Processing",
          title: "Event processed",
          subtitle: "Resource fetch completed",
          status: "processed",
          timestamp: record.processed_at
        ),
        *sync_runs.map do |sync|
          WebhookTimelineItemDto.new(
            type: "Sync",
            title: "#{sync.operation.humanize} #{sync.resource_type}",
            subtitle: sync.error_message.presence || "Stats #{sync.stats.presence || {}}",
            status: sync.status,
            timestamp: sync.completed_at || sync.started_at
          )
        end,
        *request_logs.map do |log|
          WebhookTimelineItemDto.new(
            type: "API",
            title: "#{log.method} #{log.path}",
            subtitle: log.error_message.presence || "Status #{log.status_code || "n/a"} · #{log.duration_ms || 0}ms",
            status: log.error_class.present? ? "failed" : "ready",
            timestamp: log.created_at
          )
        end
      ].compact.sort_by(&:timestamp).reverse
    end

    private_class_method :preflight_checks, :timeline
  end
end
