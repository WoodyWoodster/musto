module Vitable
  ConnectionDetailDto = Data.define(
    :id,
    :organization_name,
    :organization_external_id,
    :provider,
    :environment,
    :status,
    :api_key_reference,
    :webhook_secret_reference,
    :credentials_present,
    :webhook_secret_present,
    :last_synced_at,
    :metadata,
    :metrics,
    :health_checks,
    :endpoint_coverage,
    :webhook_events,
    :sync_runs,
    :request_logs,
    :timeline,
    :api_snapshot,
    :simulator
  ) do
    RESOURCE_TYPES = %w[employee enrollment benefit_plan payroll_deduction].freeze

    def self.from_record(record, webhook_events:, sync_runs:, request_logs:)
      event_dtos = webhook_events.map { |event| Operations::IntegrationWebhookEventDto.from_record(event) }
      sync_dtos = sync_runs.map { |sync| Operations::SyncRunDto.from_record(sync) }
      request_log_dtos = request_logs.map { |log| Operations::ApiRequestLogDto.from_record(log) }
      metadata = record.metadata || {}

      new(
        id: record.id,
        organization_name: record.organization.name,
        organization_external_id: record.organization.external_id,
        provider: record.provider,
        environment: record.environment,
        status: record.status,
        api_key_reference: record.api_key_reference,
        webhook_secret_reference: record.webhook_secret_reference,
        credentials_present: record.credentials_present?,
        webhook_secret_present: record.webhook_secret_present?,
        last_synced_at: record.last_synced_at,
        metadata:,
        metrics: metrics(record, webhook_events, sync_runs, request_logs),
        health_checks: health_checks(record),
        endpoint_coverage: endpoint_coverage(webhook_events),
        webhook_events: event_dtos,
        sync_runs: sync_dtos,
        request_logs: request_log_dtos,
        timeline: timeline(webhook_events, sync_runs, request_logs),
        api_snapshot: ApiSnapshotDto.from_metadata(metadata),
        simulator: WebhookSimulatorDto.default
      )
    end

    def credentials_missing?
      !credentials_present
    end

    def docs_url
      metadata.fetch("docs", "https://developer.vitablehealth.com/")
    end

    def ruby_docs_url
      "https://developer.vitablehealth.com/api/ruby"
    end

    def webhooks_docs_url
      "https://developer.vitablehealth.com/webhooks/introduction"
    end

    def self.metrics(record, webhook_events, sync_runs, request_logs)
      [
        ConnectionMetricDto.new(label: "Webhook events", value: webhook_events.count, status: webhook_events.any? ? "ready" : "needs_review"),
        ConnectionMetricDto.new(label: "Sync runs", value: sync_runs.count, status: sync_runs.any? ? "ready" : "pending"),
        ConnectionMetricDto.new(label: "API logs", value: request_logs.count, status: request_logs.any? ? "ready" : "pending"),
        ConnectionMetricDto.new(label: "Credentials", value: record.credentials_present? ? "Present" : "Missing", status: record.credentials_present? ? "ready" : "needs_credentials")
      ]
    end

    def self.health_checks(record)
      [
        ConnectionHealthCheckDto.new(
          label: "API key reference",
          status: record.credentials_present? ? "ready" : "needs_credentials",
          detail: record.credentials_present? ? "#{record.api_key_reference} is available to the Rails process" : "Set #{record.api_key_reference} before live resource fetches"
        ),
        ConnectionHealthCheckDto.new(
          label: "Webhook secret reference",
          status: webhook_secret_status(record),
          detail: webhook_secret_detail(record)
        ),
        ConnectionHealthCheckDto.new(
          label: "Organization routing",
          status: record.organization.external_id.present? ? "ready" : "needs_review",
          detail: record.organization.external_id.presence || "Set an organization external ID that Vitable webhooks can reference"
        ),
        ConnectionHealthCheckDto.new(
          label: "Connection status",
          status: record.status,
          detail: "Current status is #{record.status.humanize.downcase}"
        )
      ]
    end

    def self.endpoint_coverage(webhook_events)
      RESOURCE_TYPES.map do |resource_type|
        matching_events = webhook_events.select { |event| event.resource_type == resource_type }
        EndpointCoverageDto.new(
          resource_type:,
          fetch_path: "/#{resource_type.pluralize}/:id",
          events_count: matching_events.count,
          status: matching_events.any? ? "ready" : "needs_review",
          last_seen_at: matching_events.map(&:created_at).compact.max
        )
      end
    end

    def self.webhook_secret_status(record)
      record.webhook_secret_present? ? "ready" : "needs_review"
    end

    def self.webhook_secret_detail(record)
      return "#{record.webhook_secret_reference} is available to verify webhook signatures" if record.webhook_secret_present?

      record.webhook_secret_reference.presence || "Add a webhook secret env var reference before accepting signed production webhooks"
    end

    def self.timeline(webhook_events, sync_runs, request_logs)
      [
        *webhook_events.map do |event|
          ConnectionTimelineItemDto.new(
            type: "Webhook",
            title: event.event_name,
            subtitle: "#{event.resource_type} #{event.resource_id}",
            status: event.status,
            timestamp: event.created_at
          )
        end,
        *sync_runs.map do |sync|
          ConnectionTimelineItemDto.new(
            type: "Sync",
            title: "#{sync.operation.humanize} #{sync.resource_type}",
            subtitle: sync.error_message.presence || "Started #{sync.started_at.strftime('%b %-d, %I:%M %p')}",
            status: sync.status,
            timestamp: sync.completed_at || sync.started_at
          )
        end,
        *request_logs.map do |log|
          ConnectionTimelineItemDto.new(
            type: "API",
            title: "#{log.method} #{log.path}",
            subtitle: log.error_message.presence || "Status #{log.status_code || "n/a"}",
            status: log.error_class.present? ? "failed" : "ready",
            timestamp: log.created_at
          )
        end
      ].compact.sort_by(&:timestamp).reverse
    end

    private_class_method :metrics, :health_checks, :endpoint_coverage, :webhook_secret_status, :webhook_secret_detail, :timeline
  end
end
