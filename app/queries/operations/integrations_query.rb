module Operations
  class IntegrationsQuery
    def call
      {
        connections: IntegrationConnection.includes(:organization).order(created_at: :desc),
        webhooks: WebhookEvent.order(created_at: :desc).limit(20),
        sync_runs: SyncRun.recent_first.limit(20),
        request_logs: ApiRequestLog.recent_first.limit(20)
      }
    end
  end
end
