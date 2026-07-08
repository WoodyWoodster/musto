module Vitable
  ConnectionDetailDto = Data.define(
    :id,
    :organization_name,
    :organization_external_id,
    :provider,
    :environment,
    :api_base_url,
    :sdk_environment,
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
    ENDPOINT_CATALOG = [
      {
        resource_type: "auth tokens",
        method: "POST",
        fetch_path: "/v1/auth/access-tokens",
        operations: %w[auth.issue_access_token auth.issue_employee_access_token auth.issue_employer_access_token],
        sync_operations: %w[embedded_enrollment_token embedded_admin_token widget_token_broker demo_smoke_check]
      },
      {
        resource_type: "employers",
        method: "GET/POST",
        fetch_path: "/v1/employers",
        operations: %w[employer.list employer.create employer.retrieve],
        sync_operations: %w[employer_create api_snapshot_refresh demo_smoke_check],
        resource_fetch_fragments: %w[/employers/],
        fetch_resource_types: %w[employer],
        snapshot_count_key: "remote_employer_count",
        event_resource_types: %w[employer]
      },
      {
        resource_type: "employer settings",
        method: "PUT",
        fetch_path: "/v1/employers/:id/settings",
        operations: %w[employer.update_settings],
        sync_operations: %w[employer_settings_update]
      },
      {
        resource_type: "eligibility policy creation",
        method: "POST",
        fetch_path: "/v1/employers/:id/benefit-eligibility-policies",
        operations: %w[employer.eligibility_policy.create],
        sync_operations: %w[employer_create employer_settings_update]
      },
      {
        resource_type: "eligibility policy retrieval",
        method: "GET",
        fetch_path: "/v1/benefit-eligibility-policies/:id",
        operations: %w[eligibility_policy.retrieve],
        sync_operations: %w[api_snapshot_refresh],
        resource_fetch_fragments: %w[/benefit-eligibility-policies/],
        fetch_resource_types: %w[eligibility_policy benefit_eligibility_policy]
      },
      {
        resource_type: "census sync",
        method: "POST",
        fetch_path: "/v1/employers/:id/census-sync",
        operations: %w[employer.census_sync],
        sync_operations: %w[census_sync]
      },
      {
        resource_type: "remote roster",
        method: "GET",
        fetch_path: "/v1/employers/:id/employees",
        operations: %w[employer.list_employees],
        sync_operations: %w[remote_roster_refresh demo_smoke_check],
        snapshot_count_key: "mapped_employee_count"
      },
      {
        resource_type: "employees",
        method: "GET",
        fetch_path: "/v1/employees/:id",
        operations: %w[employee.retrieve],
        resource_fetch_fragments: %w[/employees/],
        fetch_resource_types: %w[employee],
        snapshot_count_key: "retrieved_remote_employee_count",
        event_resource_types: %w[employee]
      },
      {
        resource_type: "employee enrollments",
        method: "GET",
        fetch_path: "/v1/employees/:id/enrollments",
        operations: %w[employee.list_enrollments],
        sync_operations: %w[api_snapshot_refresh demo_smoke_check],
        snapshot_count_key: "remote_employee_enrollment_count"
      },
      {
        resource_type: "enrollments",
        method: "GET",
        fetch_path: "/v1/enrollments/:id",
        operations: %w[enrollment.retrieve],
        resource_fetch_fragments: %w[/enrollments/],
        fetch_resource_types: %w[enrollment],
        event_resource_types: %w[enrollment]
      },
      {
        resource_type: "plans",
        method: "GET",
        fetch_path: "/v1/plans",
        operations: %w[plan.list],
        sync_operations: %w[plan_mapping_refresh api_snapshot_refresh demo_smoke_check],
        snapshot_count_key: "remote_plan_count"
      },
      {
        resource_type: "groups",
        method: "GET/POST/PATCH",
        fetch_path: "/v1/groups",
        operations: %w[group.list group.retrieve group.create group.update],
        sync_operations: %w[care_group_upsert api_snapshot_refresh demo_smoke_check],
        fetch_resource_types: %w[group],
        snapshot_count_key: "remote_group_count",
        event_resource_types: %w[group]
      },
      {
        resource_type: "group member sync",
        method: "POST/GET",
        fetch_path: "/v1/groups/:id/members/sync",
        operations: %w[group.member_sync.submit group.member_sync.retrieve],
        sync_operations: %w[care_member_sync_submit care_member_sync_refresh]
      },
      {
        resource_type: "webhook events",
        method: "GET",
        fetch_path: "/v1/webhook-events",
        operations: %w[webhook_event.list webhook_event.retrieve webhook_event.list_deliveries],
        sync_operations: %w[webhook_replay webhook_delivery_refresh api_snapshot_refresh demo_smoke_check],
        fetch_resource_types: %w[webhook_event],
        snapshot_count_key: "remote_webhook_event_count"
      },
      {
        resource_type: "payload-only webhooks",
        method: "WEBHOOK",
        fetch_path: "/api/v1/webhooks/vitable",
        operations: %w[webhook.payload_only],
        event_resource_types: %w[dependent payroll_deduction plan_year]
      }
    ].freeze
    NON_READY_ENDPOINT_STATUSES = %w[failed needs_credentials blocked running].freeze

    def self.endpoint_catalog
      ENDPOINT_CATALOG
    end

    def self.from_record(record, webhook_events:, sync_runs:, request_logs:, simulator_resource_ids: {})
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
        api_base_url: record.effective_api_base_url,
        sdk_environment: record.sdk_environment,
        status: record.status,
        api_key_reference: record.api_key_reference,
        webhook_secret_reference: record.webhook_secret_reference,
        credentials_present: record.credentials_present?,
        webhook_secret_present: record.webhook_secret_present?,
        last_synced_at: record.last_synced_at,
        metadata:,
        metrics: metrics(record, webhook_events, sync_runs, request_logs),
        health_checks: health_checks(record),
        endpoint_coverage: endpoint_coverage(webhook_events, sync_runs, request_logs, metadata),
        webhook_events: event_dtos,
        sync_runs: sync_dtos,
        request_logs: request_log_dtos,
        timeline: timeline(webhook_events, sync_runs, request_logs),
        api_snapshot: ApiSnapshotDto.from_metadata(metadata),
        simulator: WebhookSimulatorDto.from_resource_ids(simulator_resource_ids)
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
          label: "API target",
          status: "ready",
          detail: api_target_detail(record)
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

    def self.endpoint_coverage(webhook_events, sync_runs, request_logs, metadata)
      endpoint_catalog.map do |endpoint|
        activity = endpoint_activity(endpoint, webhook_events, sync_runs, request_logs)
        EndpointCoverageDto.new(
          resource_type: endpoint.fetch(:resource_type),
          fetch_path: endpoint.fetch(:fetch_path),
          operation: endpoint.fetch(:operations).join(", "),
          method: endpoint.fetch(:method),
          activity_count: activity.count,
          status: endpoint_status(endpoint, activity, metadata),
          last_seen_at: activity.filter_map { |entry| entry.fetch(:timestamp) }.max
        )
      end
    end

    def self.endpoint_activity(endpoint, webhook_events, sync_runs, request_logs)
      [
        *matching_request_logs(endpoint, request_logs).map { |log| endpoint_activity_entry(log.created_at, log.error_class.present? ? "failed" : "ready") },
        *matching_sync_runs(endpoint, sync_runs).map { |sync| endpoint_activity_entry(sync.completed_at || sync.started_at, sync.status) },
        *matching_webhook_events(endpoint, webhook_events).map { |event| endpoint_activity_entry(event.created_at, event.status) }
      ]
    end

    def self.matching_request_logs(endpoint, request_logs)
      request_logs.select do |log|
        endpoint.fetch(:operations).include?(log.operation) ||
          endpoint.fetch(:resource_fetch_fragments, []).any? do |fragment|
            log.operation == "resource.fetch" && log.path.to_s.include?(fragment)
          end
      end
    end

    def self.matching_sync_runs(endpoint, sync_runs)
      sync_runs.select do |sync|
        endpoint.fetch(:sync_operations, []).include?(sync.operation) ||
          (sync.operation == "fetch" && endpoint.fetch(:fetch_resource_types, []).include?(sync.resource_type))
      end
    end

    def self.matching_webhook_events(endpoint, webhook_events)
      webhook_events.select { |event| endpoint.fetch(:event_resource_types, []).include?(event.resource_type) }
    end

    def self.endpoint_activity_entry(timestamp, status)
      { timestamp:, status: }
    end

    def self.endpoint_status(endpoint, activity, metadata)
      latest_status = activity.select { |entry| entry.fetch(:timestamp).present? }.max_by { |entry| entry.fetch(:timestamp) }&.fetch(:status)
      return latest_status if NON_READY_ENDPOINT_STATUSES.include?(latest_status)
      return "ready" if activity.any? || snapshot_count(metadata, endpoint.fetch(:snapshot_count_key, nil)).positive?

      "pending"
    end

    def self.snapshot_count(metadata, key)
      return 0 if key.blank?

      metadata.to_h.dig("api_snapshot", "counts", key).to_i
    end

    def self.webhook_secret_status(record)
      record.webhook_secret_present? ? "ready" : "needs_review"
    end

    def self.webhook_secret_detail(record)
      return "#{record.webhook_secret_reference} is available to verify webhook signatures" if record.webhook_secret_present?

      record.webhook_secret_reference.presence || "Add a webhook secret env var reference before accepting signed production webhooks"
    end

    def self.api_target_detail(record)
      if record.effective_api_base_url.present?
        "Requests target #{record.effective_api_base_url}"
      else
        "Requests use SDK environment #{record.sdk_environment || record.environment}"
      end
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

    private_class_method :metrics, :health_checks, :endpoint_coverage, :endpoint_activity, :matching_request_logs,
      :matching_sync_runs, :matching_webhook_events, :endpoint_activity_entry, :endpoint_status, :snapshot_count,
      :webhook_secret_status, :webhook_secret_detail, :api_target_detail, :timeline
  end
end
