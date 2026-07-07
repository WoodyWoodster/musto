module Vitable
  class IntegrationRepository < ApplicationRepository
    def connections
      IntegrationConnection.includes(:organization).order(created_at: :desc)
    end

    def vitable_connections
      IntegrationConnection.vitable.includes(:organization).order(created_at: :desc)
    end

    def webhooks(limit: 20)
      WebhookEvent.order(created_at: :desc).limit(limit)
    end

    def find_webhook_event(id)
      WebhookEvent.includes(integration_connection: [ :organization ]).find(id)
    end

    def sync_runs(limit: 20)
      SyncRun.recent_first.limit(limit)
    end

    def request_logs(limit: 20)
      ApiRequestLog.recent_first.limit(limit)
    end

    def integration_health
      Dashboard::IntegrationHealthDto.new(
        active: IntegrationConnection.where(status: "active").count,
        needs_credentials: IntegrationConnection.where(status: "needs_credentials").count,
        pending_webhooks: WebhookEvent.unprocessed.count
      )
    end

    def connection_for_organization_external_id(external_id)
      organization = Organization.find_by(external_id:)
      vitable_connection_for(organization)
    end

    def find_connection(id)
      IntegrationConnection.find(id)
    end

    def find_connection_with_organization(id)
      IntegrationConnection.includes(:organization).find(id)
    end

    def demo_smoke_connection(environment:, api_key_reference:)
      IntegrationConnection.vitable.includes(:organization).find_by(environment:) ||
        bootstrap_demo_smoke_connection(environment:, api_key_reference:)
    end

    def connection_webhook_events(connection, limit: 12)
      connection.webhook_events.order(created_at: :desc).limit(limit)
    end

    def connection_sync_runs(connection, limit: 12)
      connection.sync_runs.recent_first.limit(limit)
    end

    def connection_request_logs(connection, limit: 12)
      connection.api_request_logs.recent_first.limit(limit)
    end

    def find_event(event_id)
      WebhookEvent.find_by(event_id:)
    end

    def persist_event(dto, connection, signature_verification: nil)
      existing_event = find_event(dto.event_id)
      if existing_event
        existing_event.update!(existing_event_attributes(existing_event, connection, signature_verification))
        return existing_event
      end

      WebhookEvent.create!(event_id: dto.event_id) do |event|
        event.assign_attributes(dto.to_event_attributes)
        event.integration_connection = connection
        event.status = "received"
        event.metadata = event_metadata(event.metadata, signature_verification)
      end
    end

    def mark_unmatched_organization(event, organization_external_id)
      event.update!(
        status: "unmatched_organization",
        error_message: "No Vitable connection matched #{organization_external_id}"
      )
    end

    def mark_needs_credentials(event, connection)
      event.update!(
        status: "needs_credentials",
        error_message: "#{connection.api_key_reference} is not configured"
      )
    end

    def reconcile_webhook_resource(event, response)
      response_hash = serialize_response(response)
      WebhookReconciliationRepository.new(event:, response_hash:).call
    end

    def mark_processed(event, response: nil, reconciliation: nil)
      processed_at = Time.current
      attributes = {
        status: "processed",
        processed_at:,
        error_message: nil
      }
      if response || reconciliation
        metadata = event.metadata.to_h
        metadata["resource_snapshot"] = resource_snapshot(event, response, processed_at) if response
        metadata["resource_reconciliation"] = reconciliation.to_metadata if reconciliation
        attributes[:metadata] = metadata
      end

      event.update!(attributes)
    end

    def mark_failed(event, errors)
      event.update!(status: "failed", error_message: Array(errors).join(", "))
    end

    def mark_connection_needs_credentials(connection)
      update_connection_verification(
        connection,
        status: "needs_credentials",
        verification: {
          status: "needs_credentials",
          message: "#{connection.api_key_reference} is not configured",
          checked_at: Time.current.iso8601
        }
      )
    end

    def mark_connection_active(connection)
      update_connection_verification(
        connection,
        status: "active",
        last_synced_at: Time.current,
        verification: {
          status: "active",
          message: "Credentials verified",
          checked_at: Time.current.iso8601
        }
      )
    end

    def mark_connection_failed(connection, error)
      update_connection_verification(
        connection,
        status: "failed",
        verification: {
          status: "failed",
          message: error.message,
          error_class: error.class.name,
          checked_at: Time.current.iso8601
        }
      )
    end

    def replay_payload(event)
      (event.payload || {}).merge(
        event_id: event.event_id,
        organization_id: event.organization_external_id,
        event_name: event.event_name,
        resource_type: event.resource_type,
        resource_id: event.resource_id,
        created_at: event.occurred_at.iso8601
      )
    end

    def reset_event_for_replay(event)
      event.update!(status: "received", processed_at: nil, error_message: nil)
    end

    def related_sync_runs(event, limit: 12)
      return [] unless event.integration_connection

      event.integration_connection.sync_runs.recent_first.select do |sync|
        stats = sync.stats.to_h
        matches_resource = sync.resource_type == event.resource_type && [ stats["resource_id"], stats[:resource_id] ].include?(event.resource_id)
        matches_webhook_event = sync.resource_type == "webhook_event" && [ stats["resource_id"], stats[:resource_id] ].include?(event.event_id)
        matches_resource || matches_webhook_event
      end.first(limit)
    end

    def related_request_logs(event, limit: 12)
      return [] unless event.integration_connection

      event.integration_connection.api_request_logs.recent_first.select do |log|
        haystack = [ log.operation, log.path, log.request_body.to_json, log.response_body.to_json ].join(" ")
        haystack.include?(event.resource_type) || haystack.include?(event.resource_id)
      end.first(limit)
    end

    def create_sync_run(connection:, resource_type:, resource_id:)
      connection.sync_runs.create!(
        resource_type:,
        operation: "fetch",
        status: "running",
        started_at: Time.current,
        stats: { resource_id: }
      )
    end

    def succeed_sync_run(sync_run, response)
      response_hash = serialize_response(response)
      completed_at = Time.current
      sync_run.update!(
        status: "succeeded",
        completed_at:,
        stats: sync_run.stats.to_h.merge(
          "response_class" => response.class.name,
          "remote_response" => response_hash,
          "fetched_at" => completed_at.iso8601
        )
      )
      sync_run
    end

    def fail_sync_run(sync_run, error)
      sync_run&.update!(status: "failed", completed_at: Time.current, error_message: error.message)
      sync_run
    end

    def create_webhook_delivery_run(event:, requested_by:)
      event.integration_connection.sync_runs.create!(
        resource_type: "webhook_event",
        operation: "webhook_delivery_refresh",
        status: "running",
        started_at: Time.current,
        stats: {
          "requested_by" => requested_by,
          "resource_id" => event.event_id,
          "webhook_event_id" => event.id,
          "endpoint" => "/v1/webhook-events/:event_id/deliveries"
        }
      )
    end

    def mark_webhook_delivery_needs_credentials(sync_run)
      message = "#{sync_run.integration_connection.api_key_reference} is not configured"
      sync_run.update!(
        status: "needs_credentials",
        completed_at: Time.current,
        error_message: message,
        stats: sync_run.stats.to_h.merge("blocked_reason" => message)
      )
      sync_run
    end

    def succeed_webhook_delivery_run(event, sync_run, response)
      response_hash = serialize_response(response)
      deliveries = response_hash.fetch("data", [])
      refreshed_at = Time.current.iso8601
      event.update!(
        metadata: event.metadata.to_h.merge(
          "delivery_snapshot" => {
            "refreshed_at" => refreshed_at,
            "delivery_count" => deliveries.count,
            "deliveries" => deliveries
          }
        )
      )
      sync_run.update!(
        status: "succeeded",
        completed_at: Time.current,
        error_message: nil,
        stats: sync_run.stats.to_h.merge(
          "remote_response" => response_hash,
          "delivery_count" => deliveries.count,
          "refreshed_at" => refreshed_at
        )
      )
      sync_run
    end

    def fail_webhook_delivery_run(sync_run, error)
      sync_run&.update!(
        status: "failed",
        completed_at: Time.current,
        error_message: error.message,
        stats: sync_run.stats.to_h.merge("error_class" => error.class.name)
      )
      sync_run
    end

    def create_api_snapshot_run(connection:, requested_by:)
      connection.sync_runs.create!(
        resource_type: "connection",
        operation: "api_snapshot_refresh",
        status: "running",
        started_at: Time.current,
        stats: {
          "requested_by" => requested_by,
          "resource_id" => "connection_#{connection.id}",
          "endpoints" => %w[/v1/employers /v1/groups /v1/plans /v1/webhook-events /v1/employees/:id/enrollments]
        }
      )
    end

    def succeed_api_snapshot_run(connection, sync_run, snapshot)
      refreshed_at = Time.current
      webhook_ingestion = ingest_remote_webhook_events(connection, snapshot.fetch("webhook_events", []), refreshed_at:)
      snapshot = snapshot.merge("webhook_event_ingestion" => webhook_ingestion)
      counts = snapshot_counts(snapshot)
      connection.update!(
        status: "active",
        last_synced_at: refreshed_at,
        metadata: connection.metadata.to_h.merge(
          "api_snapshot" => snapshot.merge(
            "refreshed_at" => refreshed_at.iso8601,
            "counts" => counts
          )
        )
      )
      sync_run.update!(
        status: "succeeded",
        completed_at: refreshed_at,
        error_message: nil,
        stats: sync_run.stats.to_h.merge(counts).merge(
          "refreshed_at" => refreshed_at.iso8601,
          "webhook_event_ingestion" => webhook_ingestion
        )
      )
      sync_run
    end

    def fail_api_snapshot_run(connection, sync_run, error)
      connection.update!(
        status: "failed",
        metadata: connection.metadata.to_h.merge(
          "api_snapshot_error" => {
            "message" => error.message,
            "error_class" => error.class.name,
            "checked_at" => Time.current.iso8601
          }
        )
      )
      sync_run&.update!(
        status: "failed",
        completed_at: Time.current,
        error_message: error.message,
        stats: sync_run.stats.to_h.merge("error_class" => error.class.name)
      )
      sync_run
    end

    def create_demo_smoke_run(connection:, requested_by:)
      connection.sync_runs.create!(
        resource_type: "connection",
        operation: "demo_smoke_check",
        status: "running",
        started_at: Time.current,
        stats: {
          "requested_by" => requested_by,
          "resource_id" => "connection_#{connection.id}",
          "environment" => connection.environment,
          "base_url" => connection.effective_api_base_url,
          "endpoints" => %w[
            /v1/auth/access-tokens
            /v1/employers
            /v1/employers/:id
            /v1/employers/:id/employees
            /v1/employees/:id/enrollments
            /v1/groups
            /v1/groups/:id
            /v1/plans
            /v1/webhook-events
          ]
        }
      )
    end

    def mark_demo_smoke_needs_credentials(sync_run)
      message = "#{sync_run.integration_connection.api_key_reference} is not configured"
      sync_run.update!(
        status: "needs_credentials",
        completed_at: Time.current,
        error_message: message,
        stats: sync_run.stats.to_h.merge("blocked_reason" => message)
      )
      sync_run
    end

    def succeed_demo_smoke_run(connection, sync_run, result)
      result_hash = result.to_h
      checked_at = Time.current
      connection.update!(
        status: "active",
        last_synced_at: checked_at,
        metadata: connection.metadata.to_h.merge("demo_smoke_check" => result_hash)
      )
      sync_run.update!(
        status: "succeeded",
        completed_at: checked_at,
        error_message: nil,
        stats: sync_run.stats.to_h.merge(result_hash)
      )
      sync_run
    end

    def fail_demo_smoke_run(sync_run, error)
      sync_run&.update!(
        status: "failed",
        completed_at: Time.current,
        error_message: error.message,
        stats: sync_run.stats.to_h.merge("error_class" => error.class.name)
      )
      sync_run
    end

    private

    def bootstrap_demo_smoke_connection(environment:, api_key_reference:)
      organization = Organization.first_or_create!(
        external_id: "org_musto_demo_smoke",
        name: "Musto Demo Smoke"
      )

      organization.integration_connections.create!(
        provider: "vitable",
        environment:,
        api_key_reference:,
        status: "pending",
        metadata: environment == "demo" ? { "api_base_url" => IntegrationConnection::DEMO_BASE_URL } : {}
      )
    end

    def update_connection_verification(connection, status:, verification:, last_synced_at: connection.last_synced_at)
      connection.update!(
        status:,
        last_synced_at:,
        metadata: connection.metadata.to_h.merge(last_verification: verification)
      )
      connection
    end

    def existing_event_attributes(event, connection, signature_verification)
      attributes = { metadata: event_metadata(event.metadata, signature_verification) }
      attributes[:integration_connection] = connection if event.integration_connection.blank? && connection.present?
      attributes
    end

    def event_metadata(metadata, signature_verification)
      return metadata.to_h unless signature_verification

      metadata.to_h.merge("signature_verification" => signature_verification.to_metadata)
    end

    def resource_snapshot(event, response, fetched_at)
      {
        "fetched_at" => fetched_at.iso8601,
        "resource_type" => event.resource_type,
        "resource_id" => event.resource_id,
        "response" => serialize_response(response)
      }
    end

    def snapshot_counts(snapshot)
      webhook_ingestion = snapshot.fetch("webhook_event_ingestion", {}).to_h

      {
        "remote_employer_count" => snapshot.fetch("employers", []).count,
        "remote_group_count" => snapshot.fetch("groups", []).count,
        "remote_plan_count" => snapshot.fetch("plans", []).count,
        "remote_webhook_event_count" => snapshot.fetch("webhook_events", []).count,
        "remote_employee_enrollment_count" => snapshot.fetch("employee_enrollments", []).sum { |entry| entry.fetch("enrollments", []).count },
        "imported_webhook_event_count" => webhook_ingestion.fetch("created_count", 0),
        "existing_webhook_event_count" => webhook_ingestion.fetch("existing_count", 0)
      }
    end

    def ingest_remote_webhook_events(connection, remote_events, refreshed_at:)
      created_event_ids = []
      existing_event_ids = []
      skipped_event_ids = []

      remote_events.each do |remote_event|
        dto = RemoteWebhookEventDto.from_remote_event(
          remote_event,
          default_organization_id: connection.organization.external_id
        )

        if dto.blank?
          skipped_event_ids << RemoteWebhookEventDto.remote_event_id(remote_event)
          next
        end

        event = WebhookEvent.find_or_initialize_by(event_id: dto.event_id)
        if event.persisted?
          existing_event_ids << event.event_id
        else
          event.status = "received"
          created_event_ids << dto.event_id
        end

        event.assign_attributes(remote_webhook_event_attributes(dto, connection, refreshed_at:, existing_event: event))
        event.save!
      end

      {
        "source" => "vitable_webhook_events_api",
        "created_count" => created_event_ids.count,
        "existing_count" => existing_event_ids.count,
        "skipped_count" => skipped_event_ids.count,
        "created_event_ids" => created_event_ids,
        "existing_event_ids" => existing_event_ids,
        "skipped_event_ids" => skipped_event_ids,
        "refreshed_at" => refreshed_at.iso8601
      }
    end

    def remote_webhook_event_attributes(dto, connection, refreshed_at:, existing_event:)
      metadata = existing_event.metadata.to_h.merge(
        "remote_webhook_event_snapshot" => {
          "source" => "vitable_webhook_events_api",
          "refreshed_at" => refreshed_at.iso8601
        }
      )

      dto.to_event_attributes.merge(
        integration_connection: existing_event.integration_connection || connection,
        payload: existing_event.payload.to_h.merge(dto.payload),
        metadata:
      )
    end

    def serialize_response(response)
      serialized = if response.blank?
        {}
      elsif response.respond_to?(:deep_to_h)
        response.deep_to_h
      elsif response.respond_to?(:to_h)
        response.to_h
      else
        { value: response.to_s }
      end

      redact_token_values(serialized.deep_stringify_keys)
    end

    def redact_token_values(value)
      case value
      when Hash
        value.to_h do |key, entry|
          [ key, key == "access_token" ? "[FILTERED]" : redact_token_values(entry) ]
        end
      when Array
        value.map { |entry| redact_token_values(entry) }
      else
        value
      end
    end
  end
end
