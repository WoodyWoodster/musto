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

    def find_event(event_id)
      WebhookEvent.find_by(event_id:)
    end

    def persist_event(dto, connection)
      find_event(dto.event_id) || WebhookEvent.create!(event_id: dto.event_id) do |event|
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
  end
end
