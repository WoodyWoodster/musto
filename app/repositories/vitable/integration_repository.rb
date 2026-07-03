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
      organization&.integration_connections&.vitable&.find_by(environment: "production") ||
        organization&.integration_connections&.vitable&.first
    end

    def find_connection(id)
      IntegrationConnection.find(id)
    end

    def find_connection_with_organization(id)
      IntegrationConnection.includes(:organization).find(id)
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

    def persist_event(dto, connection)
      existing_event = find_event(dto.event_id)
      if existing_event
        existing_event.update!(integration_connection: connection) if existing_event.integration_connection.blank? && connection.present?
        return existing_event
      end

      WebhookEvent.create!(event_id: dto.event_id) do |event|
        event.assign_attributes(dto.to_event_attributes)
        event.integration_connection = connection
        event.status = "received"
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

    def mark_processed(event)
      event.update!(status: "processed", processed_at: Time.current, error_message: nil)
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
        sync.resource_type == event.resource_type && [ stats["resource_id"], stats[:resource_id] ].include?(event.resource_id)
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
      sync_run.update!(
        status: "succeeded",
        completed_at: Time.current,
        stats: sync_run.stats.merge(response_class: response.class.name)
      )
      sync_run
    end

    def fail_sync_run(sync_run, error)
      sync_run&.update!(status: "failed", completed_at: Time.current, error_message: error.message)
      sync_run
    end

    private

    def update_connection_verification(connection, status:, verification:, last_synced_at: connection.last_synced_at)
      connection.update!(
        status:,
        last_synced_at:,
        metadata: connection.metadata.to_h.merge(last_verification: verification)
      )
      connection
    end
  end
end
