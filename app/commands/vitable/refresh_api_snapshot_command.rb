module Vitable
  class RefreshApiSnapshotCommand < ApplicationCommand
    MAX_RECOVERED_WEBHOOK_EVENTS = 25

    def initialize(dto:, repository: IntegrationRepository.new, gateway_class: ClientGateway)
      @dto = dto
      @repository = repository
      @gateway_class = gateway_class
    end

    def call
      connection = @repository.find_connection(@dto.connection_id)
      sync_run = @repository.create_api_snapshot_run(connection:, requested_by: @dto.requested_by)

      unless connection.credentials_present?
        @repository.mark_connection_needs_credentials(connection)
        sync_run.update!(
          status: "needs_credentials",
          completed_at: Time.current,
          error_message: "#{connection.api_key_reference} is not configured",
          stats: sync_run.stats.to_h.merge("blocked_reason" => "#{connection.api_key_reference} is not configured")
        )
        return failure(record: sync_run, errors: "#{connection.api_key_reference} is not configured")
      end

      snapshot = build_snapshot(connection)
      sync_run = @repository.succeed_api_snapshot_run(connection, sync_run, snapshot)
      recovery = recover_webhook_events(connection, sync_run)
      sync_run = @repository.record_api_snapshot_webhook_recovery(connection, sync_run, recovery)
      success(record: sync_run, value: connection.reload.metadata.fetch("api_snapshot"))
    rescue VitableConnect::Errors::APIError => e
      @repository.fail_api_snapshot_run(connection, sync_run, e)
      failure(record: sync_run, errors: "#{e.class}: #{e.message}")
    rescue ActiveRecord::RecordInvalid => e
      failure(record: e.record, errors: e.record.errors.full_messages)
    end

    private

    def build_snapshot(connection)
      gateway = @gateway_class.new(connection)
      refreshed_at = Time.current.iso8601
      webhook_event_query = webhook_event_query(connection)
      employers = page_data(gateway.list_all_employers)
      groups = page_data(gateway.list_all_groups)
      plans = page_data(gateway.list_all_plans)
      employer_reconciliation = RemoteEmployerSnapshotRepository.new(connection:).reconcile_snapshot(
        remote_employers: employers,
        source: "vitable_api_snapshot",
        refreshed_at:
      )
      group_reconciliation = RemoteGroupSnapshotRepository.new(connection:).reconcile_snapshot(
        remote_groups: groups,
        source: "vitable_api_snapshot",
        refreshed_at:
      )
      plan_reconciliation = plan_reconciliation_snapshots(connection, plans, refreshed_at:)
      remote_employee_rosters = remote_employee_rosters(gateway, connection)
      employee_reconciliation = RemoteEmployeeSnapshotRepository.new(connection:).reconcile_snapshot(
        snapshot_entries: remote_employee_rosters,
        source: "vitable_api_snapshot",
        refreshed_at:
      )
      employee_enrollments = employee_enrollment_snapshot(gateway, connection)
      enrollment_reconciliation = EnrollmentSnapshotRepository.new(connection:).reconcile_snapshot(
        snapshot_entries: employee_enrollments,
        source: "vitable_api_snapshot",
        refreshed_at:
      )

      {
        "requested_by" => @dto.requested_by,
        "employers" => employers,
        "employer_reconciliation" => employer_reconciliation.to_metadata,
        "groups" => groups,
        "group_reconciliation" => group_reconciliation.to_metadata,
        "plans" => plans,
        "plan_reconciliation" => plan_reconciliation,
        "webhook_event_query" => webhook_event_query_metadata(webhook_event_query),
        "webhook_events" => page_data(gateway.list_all_webhook_events(**webhook_event_query)),
        "remote_employee_rosters" => remote_employee_rosters,
        "employee_reconciliation" => employee_reconciliation.to_metadata,
        "employee_enrollments" => employee_enrollments,
        "enrollment_reconciliation" => enrollment_reconciliation.to_metadata
      }
    end

    def recover_webhook_events(connection, sync_run)
      ingestion = sync_run.stats.to_h.fetch("webhook_event_ingestion", {}).to_h
      event_ids = (
        ingestion.fetch("created_event_ids", []) +
        ingestion.fetch("existing_event_ids", [])
      ).uniq
      return webhook_recovery_result(candidate_event_ids: event_ids) if event_ids.empty?

      scope = connection.webhook_events.where(event_id: event_ids, processed_at: nil).order(:occurred_at, :id)
      candidate_count = scope.count
      events = scope.limit(MAX_RECOVERED_WEBHOOK_EVENTS).to_a
      limit_exceeded_count = [ candidate_count - events.count, 0 ].max
      processed_event_ids = []
      failed_events = []
      skipped_events = []

      events.each do |event|
        result = ProcessWebhookCommand.new(
          payload: @repository.replay_payload(event),
          repository: @repository,
          gateway_class: @gateway_class
        ).call
        event.reload

        if result.success? && event.processed?
          processed_event_ids << event.event_id
        elsif result.success?
          skipped_events << webhook_recovery_event(event, reason: "not_processed")
        else
          failed_events << webhook_recovery_event(event, reason: "failed", errors: result.errors)
        end
      end

      webhook_recovery_result(
        candidate_event_ids: event_ids,
        candidate_count:,
        processed_event_ids:,
        failed_events:,
        skipped_events:,
        limit_exceeded_count:
      )
    end

    def webhook_recovery_result(candidate_event_ids:, candidate_count: 0, processed_event_ids: [], failed_events: [], skipped_events: [], limit_exceeded_count: 0)
      {
        "source" => "api_snapshot_refresh",
        "candidate_event_ids" => candidate_event_ids,
        "candidate_count" => candidate_count,
        "processed_count" => processed_event_ids.count,
        "failed_count" => failed_events.count,
        "skipped_count" => skipped_events.count + limit_exceeded_count,
        "limit" => MAX_RECOVERED_WEBHOOK_EVENTS,
        "limit_exceeded_count" => limit_exceeded_count,
        "processed_event_ids" => processed_event_ids,
        "failed_events" => failed_events,
        "skipped_events" => skipped_events,
        "recovered_at" => Time.current.iso8601
      }
    end

    def webhook_recovery_event(event, reason:, errors: [])
      {
        "event_id" => event.event_id,
        "status" => event.status,
        "resource_type" => event.resource_type,
        "resource_id" => event.resource_id,
        "reason" => reason,
        "errors" => Array(errors)
      }.compact
    end

    def plan_reconciliation_snapshots(connection, remote_plans, refreshed_at:)
      local_employers(connection).map do |employer|
        snapshot = Benefits::PlanAdministrationRepository.new(employer:).reconcile_remote_plan_snapshot(
          remote_plans:,
          refreshed_at:,
          source: "vitable_api_snapshot"
        )

        {
          "local_employer_id" => employer.id,
          "employer_name" => employer.name,
          "mapped_plan_count" => snapshot.fetch("mapped_plan_count", 0),
          "unmatched_remote_count" => snapshot.fetch("unmatched_remote_plans", []).count,
          "unmatched_local_count" => snapshot.fetch("unmatched_local_plans", []).count,
          "ambiguous_remote_count" => snapshot.fetch("ambiguous_remote_plans", []).count
        }
      end
    end

    def remote_employee_rosters(gateway, connection)
      local_remote_employers(connection).map do |employer|
        {
          "local_employer_id" => employer.id,
          "remote_employer_id" => employer.vitable_id,
          "employer_name" => employer.name,
          "employees" => page_data(gateway.list_all_employer_employees(employer.vitable_id))
        }
      rescue VitableConnect::Errors::NotFoundError => e
        {
          "local_employer_id" => employer.id,
          "remote_employer_id" => employer.vitable_id,
          "employer_name" => employer.name,
          "employees" => [],
          "error_class" => e.class.name,
          "error_message" => e.message
        }
      end
    end

    def employee_enrollment_snapshot(gateway, connection)
      local_remote_employees(connection).map do |employee|
        {
          "local_employee_id" => employee.id,
          "remote_employee_id" => employee.vitable_id,
          "employee_name" => employee.full_name,
          "email" => employee.email,
          "enrollments" => page_data(gateway.list_all_employee_enrollments(employee.vitable_id))
        }
      rescue VitableConnect::Errors::NotFoundError => e
        {
          "local_employee_id" => employee.id,
          "remote_employee_id" => employee.vitable_id,
          "employee_name" => employee.full_name,
          "email" => employee.email,
          "error_class" => e.class.name,
          "error_message" => e.message
        }
      end
    end

    def local_remote_employers(connection)
      local_employers(connection)
        .where.not(vitable_id: [ nil, "" ])
    end

    def local_employers(connection)
      Employer
        .joins(:organization)
        .where(organization: connection.organization)
    end

    def local_remote_employees(connection)
      Employer
        .joins(:organization)
        .where(organization: connection.organization)
        .includes(:employees)
        .flat_map(&:employees)
        .select { |employee| employee.vitable_id.present? }
    end

    def webhook_event_query(connection)
      previous_refreshed_at = previous_api_snapshot_refreshed_at(connection)
      return {} unless previous_refreshed_at

      { created_after: previous_refreshed_at }
    end

    def previous_api_snapshot_refreshed_at(connection)
      refreshed_at = connection.metadata.to_h.dig("api_snapshot", "refreshed_at")
      return if refreshed_at.blank?

      Time.iso8601(refreshed_at.to_s)
    rescue ArgumentError
      nil
    end

    def webhook_event_query_metadata(query)
      query.transform_values do |value|
        value.respond_to?(:iso8601) ? value.iso8601 : value.to_s
      end.deep_stringify_keys
    end

    def page_data(response)
      serialize_response(response).fetch("data", [])
    end

    def serialize_response(response)
      return {} if response.blank?
      return response.deep_to_h.deep_stringify_keys if response.respond_to?(:deep_to_h)
      return response.to_h.deep_stringify_keys if response.respond_to?(:to_h)

      { "value" => response.to_s }
    end
  end
end
