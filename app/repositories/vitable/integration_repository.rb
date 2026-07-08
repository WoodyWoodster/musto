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
        existing_event.update!(existing_event_attributes(existing_event, dto, connection, signature_verification))
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

    def snapshot_only_webhook_reconciliation(event, known_payload_only_resource_type: false, known_webhook_resource_type: false)
      WebhookResourceReconciliationDto.new(
        status: "skipped",
        resource_type: event.resource_type,
        resource_id: event.resource_id,
        local_record_type: nil,
        local_record_id: nil,
        matched_by: nil,
        applied_changes: [],
        warnings: [
          snapshot_only_webhook_warning(event, known_payload_only_resource_type:, known_webhook_resource_type:)
        ]
      )
    end

    def payload_only_webhook_reconciliation(event, known_payload_only_resource_type: false, known_webhook_resource_type: false)
      return reconcile_payload_only_payroll_deduction(event) if event.resource_type == "payroll_deduction"
      return reconcile_payload_only_dependent(event) if event.resource_type == "dependent"
      return PlanYearWebhookReconciliationRepository.new(event:).call if event.resource_type == "plan_year"

      snapshot_only_webhook_reconciliation(
        event,
        known_payload_only_resource_type:,
        known_webhook_resource_type:
      )
    end

    def snapshot_only_webhook_warning(event, known_payload_only_resource_type:, known_webhook_resource_type:)
      if known_payload_only_resource_type
        return "Vitable webhook resource type #{event.resource_type} is listed by the installed SDK but has no retrieve endpoint; event was stored from the webhook payload only."
      end
      if known_webhook_resource_type
        return "Vitable SDK does not expose a retrieve endpoint for #{event.resource_type}; event was stored from the webhook payload only."
      end

      "Vitable SDK does not expose a retrieve endpoint for #{event.resource_type}, and the installed SDK does not list it as a filterable webhook resource type; event was stored from the webhook payload only."
    end

    def reconcile_webhook_resource(event, response)
      response_hash = serialize_response(response)
      WebhookReconciliationRepository.new(event:, response_hash:).call
    end

    def reconcile_fetched_resource(connection:, resource_type:, resource_id:, response:)
      response_hash = serialize_response(response)
      event = WebhookEvent.new(
        event_id: "resource_fetch_#{resource_type}_#{resource_id}",
        organization_external_id: connection.organization.external_id.presence || "organization_#{connection.organization_id}",
        event_name: "resource.fetch",
        resource_type:,
        resource_id:,
        occurred_at: Time.current,
        status: "processed",
        integration_connection: connection
      )

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

    def mark_connection_failed(connection, error, response: nil)
      checked_at = Time.current
      verification = {
        status: "failed",
        message: PayloadRedactor.error_message(error),
        error_class: error.class.name,
        checked_at: checked_at.iso8601
      }

      if response
        verification = verification.merge(
          response_class: response.class.name,
          remote_response: serialize_response(response)
        )
      end

      update_connection_verification(
        connection,
        status: "failed",
        verification:
      )
    end

    def record_connection_request_success(connection, operation:, method:, path:)
      observed_at = Time.current
      connection.update!(
        status: "active",
        last_synced_at: observed_at,
        metadata: connection.metadata.to_h.merge(
          "last_successful_request" => {
            "operation" => operation,
            "method" => method.to_s.upcase,
            "path" => path,
            "observed_at" => observed_at.iso8601
          }
        )
      )
      connection
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

    def create_webhook_replay_run(event:, requested_by:)
      event.integration_connection.sync_runs.create!(
        resource_type: "webhook_event",
        operation: "webhook_replay",
        status: "running",
        started_at: Time.current,
        stats: {
          "requested_by" => requested_by,
          "resource_id" => event.event_id,
          "webhook_event_id" => event.id,
          "webhook_resource_type" => event.resource_type,
          "webhook_resource_id" => event.resource_id,
          "previous_status" => event.status,
          "previous_processed_at" => event.processed_at&.iso8601
        }.compact
      )
    end

    def finish_webhook_replay_run(sync_run, event:, result:)
      status = event.status == "needs_credentials" ? "needs_credentials" : "succeeded"
      sync_run.update!(
        status:,
        completed_at: Time.current,
        error_message: status == "succeeded" ? nil : event.error_message,
        stats: webhook_replay_stats(sync_run, event, result:)
      )
      sync_run
    end

    def fail_webhook_replay_run(sync_run, event:, errors:)
      sync_run&.update!(
        status: "failed",
        completed_at: Time.current,
        error_message: Array(errors).join(", "),
        stats: webhook_replay_stats(sync_run, event, errors:)
      )
      sync_run
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

    def webhook_simulator_resource_ids(connection)
      employers = Employer.where(organization_id: connection.organization_id)
      employees = Employee.where(employer_id: employers.select(:id))
      enrollments = Enrollment.joins(:employee).where(employees: { employer_id: employers.select(:id) })
      snapshot_ids = webhook_simulator_snapshot_resource_ids(connection.metadata)

      {
        "enrollment" => first_present_id(
          enrollments.where.not(vitable_id: [ nil, "" ]).order(:id).pick(:vitable_id),
          snapshot_ids["enrollment"]
        ),
        "employee" => first_present_id(
          employees.where.not(vitable_id: [ nil, "" ]).order(:id).pick(:vitable_id),
          snapshot_ids["employee"]
        ),
        "employer" => first_present_id(
          employers.where.not(vitable_id: [ nil, "" ]).order(:id).pick(:vitable_id),
          snapshot_ids["employer"]
        ),
        "group" => first_present_id(
          employers.order(:id).filter_map { |employer| employer.settings.to_h.stringify_keys.fetch(CareGroupRepository::GROUP_ID_KEY, nil).presence }.first,
          snapshot_ids["group"]
        )
      }.compact
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

    def annotate_sync_run_reconciliation(sync_run, reconciliation)
      return sync_run unless sync_run && reconciliation

      sync_run.update!(
        stats: sync_run.stats.to_h.merge(
          "resource_reconciliation" => reconciliation.to_metadata
        )
      )
      sync_run
    end

    def mark_sync_run_needs_credentials(sync_run)
      message = "#{sync_run.integration_connection.api_key_reference} is not configured"
      sync_run.update!(
        status: "needs_credentials",
        completed_at: Time.current,
        error_message: message,
        stats: sync_run.stats.to_h.merge("blocked_reason" => message)
      )
      sync_run
    end

    def fail_sync_run(sync_run, error)
      sync_run&.update!(status: "failed", completed_at: Time.current, error_message: PayloadRedactor.error_message(error))
      sync_run
    end

    def fail_sync_run_after_response(sync_run, response, error)
      return unless sync_run

      response_hash = serialize_response(response)
      completed_at = Time.current
      sync_run.update!(
        status: "failed",
        completed_at:,
        error_message: PayloadRedactor.error_message(error),
        stats: sync_run.stats.to_h.merge(
          "response_class" => response.class.name,
          "remote_response" => response_hash,
          "fetched_at" => completed_at.iso8601,
          "error_class" => error.class.name
        )
      )
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
      deliveries = webhook_delivery_payloads_from_response(response_hash, expected_webhook_event_id: event.event_id)
      status_counts = webhook_delivery_status_counts(deliveries)
      refreshed_at = Time.current.iso8601
      event.update!(
        metadata: event.metadata.to_h.merge(
          "delivery_snapshot" => {
            "refreshed_at" => refreshed_at,
            "delivery_count" => deliveries.count,
            "status_counts" => status_counts,
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
          "delivery_status_counts" => status_counts,
          "refreshed_at" => refreshed_at
        )
      )
      sync_run
    end

    def fail_webhook_delivery_run(sync_run, error, response: nil)
      return unless sync_run

      completed_at = Time.current
      stats = sync_run.stats.to_h.merge("error_class" => error.class.name)

      if response
        response_hash = serialize_response(response)
        stats = stats.merge(
          "response_class" => response.class.name,
          "remote_response" => response_hash,
          "fetched_at" => completed_at.iso8601
        )
      end

      sync_run.update!(
        status: "failed",
        completed_at:,
        error_message: PayloadRedactor.error_message(error),
        stats:
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
      completed_at = Time.current
      refreshed_at = api_snapshot_refreshed_at(snapshot, fallback: completed_at)
      webhook_ingestion = ingest_remote_webhook_events(connection, snapshot.fetch("webhook_events", []), refreshed_at:)
      snapshot = snapshot.merge("webhook_event_ingestion" => webhook_ingestion)
      counts = snapshot_counts(snapshot)
      connection.update!(
        status: "active",
        last_synced_at: completed_at,
        metadata: connection.metadata.to_h.merge(
          "api_snapshot" => snapshot.merge(
            "refreshed_at" => refreshed_at.iso8601,
            "completed_at" => completed_at.iso8601,
            "counts" => counts
          )
        )
      )
      sync_run.update!(
        status: "succeeded",
        completed_at: completed_at,
        error_message: nil,
        stats: sync_run.stats.to_h.merge(counts).merge(
          "refreshed_at" => refreshed_at.iso8601,
          "completed_at" => completed_at.iso8601,
          "webhook_event_ingestion" => webhook_ingestion
        )
      )
      sync_run
    end

    def record_api_snapshot_webhook_recovery(connection, sync_run, recovery)
      counts = webhook_recovery_counts(recovery)
      metadata = connection.reload.metadata.to_h
      snapshot = metadata.fetch("api_snapshot", {}).to_h
      snapshot_counts = snapshot.fetch("counts", {}).to_h.merge(counts)
      snapshot = snapshot.merge(
        "webhook_event_recovery" => recovery,
        "counts" => snapshot_counts
      )

      connection.update!(metadata: metadata.merge("api_snapshot" => snapshot))
      sync_run.update!(
        completed_at: Time.current,
        stats: sync_run.stats.to_h.merge(counts).merge("webhook_event_recovery" => recovery)
      )
      sync_run
    end

    def fail_api_snapshot_run(connection, sync_run, error, trace: {})
      trace = trace.to_h
      error_metadata = {
        "message" => PayloadRedactor.error_message(error),
        "error_class" => error.class.name,
        "checked_at" => Time.current.iso8601
      }
      error_metadata["trace"] = trace if trace.present?

      connection.update!(
        status: "failed",
        metadata: connection.metadata.to_h.merge(
          "api_snapshot_error" => error_metadata
        )
      )
      if sync_run
        stats = sync_run.stats.to_h.merge("error_class" => error.class.name)
        stats = stats.merge("api_snapshot_trace" => trace) if trace.present?

        sync_run.update!(
          status: "failed",
          completed_at: Time.current,
          error_message: PayloadRedactor.error_message(error),
          stats:
        )
      end
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
        error_message: PayloadRedactor.error_message(error),
        stats: sync_run.stats.to_h.merge("error_class" => error.class.name)
      )
      sync_run
    end

    private

    def api_snapshot_refreshed_at(snapshot, fallback:)
      value = snapshot.to_h.fetch("refreshed_at", nil)
      return fallback if value.blank?
      return value if value.respond_to?(:iso8601) && !value.is_a?(String)

      Time.iso8601(value.to_s)
    rescue ArgumentError
      fallback
    end

    def webhook_delivery_payloads_from_response(response_hash, expected_webhook_event_id:)
      data = response_hash.fetch("data", [])
      raise ArgumentError, "Vitable webhook delivery response did not include a data array" unless data.is_a?(Array)

      data.map do |payload|
        WebhookDeliveryDto
          .from_hash(payload)
          .validate!(expected_webhook_event_id:)
          .to_snapshot_hash
      end
    end

    def webhook_delivery_status_counts(deliveries)
      deliveries.each_with_object(Hash.new(0)) do |delivery, counts|
        key = WebhookDeliveryDto.from_hash(delivery).status_key.presence || "unknown"
        counts[key] += 1
      end.to_h
    end

    def webhook_replay_stats(sync_run, event, result: nil, errors: [])
      stats = sync_run.stats.to_h.merge(
        "final_status" => event.status,
        "processed_at" => event.processed_at&.iso8601,
        "replayed_at" => Time.current.iso8601
      ).compact

      stats["result"] = serialize_response(result.value) if result
      stats["errors"] = Array(errors) if Array(errors).any?
      stats
    end

    def webhook_simulator_snapshot_resource_ids(metadata)
      snapshot = metadata.to_h.stringify_keys.fetch("api_snapshot", {}).to_h

      {
        "enrollment" => first_nested_remote_id(snapshot.fetch("employee_enrollments", []), "enrollments"),
        "employee" => first_nested_remote_id(snapshot.fetch("remote_employee_rosters", []), "employees"),
        "employer" => first_remote_id(snapshot.fetch("employers", [])),
        "group" => first_remote_id(snapshot.fetch("groups", []))
      }.compact
    end

    def first_nested_remote_id(entries, collection_key)
      Array(entries).filter_map do |entry|
        first_remote_id(entry.to_h.stringify_keys.fetch(collection_key, []))
      end.first
    end

    def first_remote_id(records)
      Array(records).filter_map { |record| record.to_h.stringify_keys.fetch("id", nil).presence }.first
    end

    def first_present_id(*values)
      values.flatten.compact_blank.first
    end

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

    def existing_event_attributes(event, dto, connection, signature_verification)
      attributes = { metadata: event_metadata(event.metadata, signature_verification) }
      attributes.merge!(dto.to_event_attributes.except(:event_id)) unless event.processed?
      attributes[:integration_connection] = connection if event.integration_connection.blank? && connection.present?
      attributes
    end

    def reconcile_payload_only_dependent(event)
      payload = dependent_payload(event)
      employee, employee_matched_by = dependent_employee_match(event, payload)
      unless employee
        return WebhookResourceReconciliationDto.new(
          status: "unmatched",
          resource_type: event.resource_type,
          resource_id: event.resource_id,
          local_record_type: nil,
          local_record_id: nil,
          matched_by: nil,
          applied_changes: [],
          warnings: [ "No local employee matched this Vitable dependent payload." ]
        )
      end

      dependent, dependent_matched_by = dependent_match(employee, payload)
      missing_fields = missing_dependent_fields(dependent, payload)
      if missing_fields.any?
        return WebhookResourceReconciliationDto.new(
          status: "skipped",
          resource_type: event.resource_type,
          resource_id: event.resource_id,
          local_record_type: "Employee",
          local_record_id: employee.id,
          matched_by: employee_matched_by,
          applied_changes: [],
          warnings: [ "Vitable dependent payload did not include #{missing_fields.to_sentence}." ]
        )
      end

      attributes = dependent_attributes(dependent, payload, event)
      if dependent
        dependent.update!(attributes)
        matched_by = dependent_matched_by
        applied_changes = dependent_applied_changes(attributes)
      else
        dependent = employee.dependents.create!(attributes)
        matched_by = "created_from_payload"
        applied_changes = [ "dependents.created" ] + dependent_applied_changes(attributes)
      end

      WebhookResourceReconciliationDto.new(
        status: "matched",
        resource_type: event.resource_type,
        resource_id: event.resource_id,
        local_record_type: "Dependent",
        local_record_id: dependent.id,
        matched_by:,
        applied_changes:,
        warnings: []
      )
    end

    def dependent_payload(event)
      payload = event.payload.to_h.stringify_keys
      resource_payload = %w[data resource object].lazy.filter_map do |key|
        value = payload.fetch(key, nil)
        value.to_h.stringify_keys if value.respond_to?(:to_h)
      end.first || payload

      resource_payload.merge(
        "id" => resource_payload.fetch("id", nil).presence || event.resource_id
      )
    end

    def dependent_employee_match(event, payload)
      scope = payload_employee_scope(event)
      employee_payload = nested_employee_payload(payload)
      reference_id = payload.fetch("employee_reference_id", nil).presence ||
        employee_payload.fetch("reference_id", nil).presence
      employee = employee_from_local_reference_id(scope, reference_id)
      return [ employee, "employee_reference_id" ] if employee

      remote_employee_id = payload.fetch("employee_id", nil).presence ||
        payload.fetch("subscriber_id", nil).presence ||
        employee_payload.fetch("id", nil).presence
      if remote_employee_id.present?
        employee = scope.find_by(vitable_id: remote_employee_id) ||
          scope.detect { |candidate| candidate.metadata.to_h.stringify_keys.fetch("vitable_member_id", nil) == remote_employee_id }
        return [ employee, "remote_employee_id" ] if employee
      end

      email = payload.fetch("employee_email", nil).presence || employee_payload.fetch("email", nil).presence
      if email.present?
        employee = employee_by_email(scope, email)
        return [ employee, "employee_email" ] if employee
      end

      [ nil, nil ]
    end

    def dependent_match(employee, payload)
      remote_id = dependent_remote_id(payload)
      if remote_id.present?
        dependent = employee.dependents.find_by(vitable_id: remote_id)
        return [ dependent, "vitable_id" ] if dependent
      end

      reference_id = payload.fetch("reference_id", nil).presence
      dependent = dependent_from_reference_id(employee, reference_id)
      return [ dependent, "reference_id" ] if dependent

      dependent = dependent_from_identity(employee, payload)
      return [ dependent, "identity" ] if dependent

      [ nil, nil ]
    end

    def dependent_from_reference_id(employee, reference_id)
      value = reference_id.to_s
      return unless value.match?(/\Amusto_dependent_\d+\z/)

      employee.dependents.find_by(id: value.delete_prefix("musto_dependent_").to_i)
    end

    def dependent_from_identity(employee, payload)
      first_name = payload.fetch("first_name", nil).to_s.downcase.presence
      last_name = payload.fetch("last_name", nil).to_s.downcase.presence
      relationship = dependent_relationship(payload)
      date_of_birth = dependent_date_of_birth(payload)
      return if [ first_name, last_name, relationship, date_of_birth ].any?(&:blank?)

      matches = employee.dependents.select do |dependent|
        dependent.first_name.to_s.downcase == first_name &&
          dependent.last_name.to_s.downcase == last_name &&
          dependent.relationship == relationship &&
          dependent.date_of_birth == date_of_birth
      end
      matches.one? ? matches.first : nil
    end

    def missing_dependent_fields(dependent, payload)
      return [] if dependent

      {
        "first_name" => payload.fetch("first_name", nil),
        "last_name" => payload.fetch("last_name", nil),
        "relationship" => dependent_relationship(payload)
      }.filter_map { |field, value| field if value.blank? }
    end

    def dependent_attributes(dependent, payload, event)
      metadata = dependent&.metadata.to_h.stringify_keys.merge(
        "vitable_last_webhook_event_id" => event.event_id,
        "vitable_last_webhook_event_name" => event.event_name,
        "vitable_last_refreshed_at" => Time.current.iso8601,
        "vitable_last_resource_snapshot" => payload.slice("id", "employee_id", "first_name", "last_name", "relationship", "date_of_birth", "status")
      ).compact

      {
        first_name: payload.fetch("first_name", nil).presence || dependent&.first_name,
        last_name: payload.fetch("last_name", nil).presence || dependent&.last_name,
        relationship: dependent_relationship(payload).presence || dependent&.relationship,
        date_of_birth: dependent_date_of_birth(payload) || dependent&.date_of_birth,
        enrollment_status: dependent_enrollment_status(payload, dependent),
        eligibility_status: dependent_eligibility_status(payload, dependent),
        vitable_id: dependent_remote_id(payload).presence || dependent&.vitable_id,
        metadata:
      }.compact
    end

    def dependent_applied_changes(attributes)
      attributes.keys.map do |key|
        key == :metadata ? "metadata.vitable_last_resource_snapshot" : key.to_s
      end
    end

    def dependent_remote_id(payload)
      payload.fetch("id", nil).presence || payload.fetch("dependent_id", nil).presence
    end

    def dependent_relationship(payload)
      payload.fetch("relationship", nil).presence ||
        payload.fetch("relationship_type", nil).presence ||
        payload.fetch("dependent_type", nil).presence
    end

    def dependent_date_of_birth(payload)
      value = payload.fetch("date_of_birth", nil).presence || payload.fetch("dob", nil).presence
      return value if value.is_a?(Date)
      return if value.blank?

      Date.iso8601(value.to_s)
    rescue ArgumentError
      nil
    end

    def dependent_enrollment_status(payload, dependent)
      status = payload.fetch("enrollment_status", nil).presence || payload.fetch("status", nil).presence
      case status.to_s.downcase
      when "active", "accepted", "eligible", "enrolled"
        "enrolled"
      when "canceled", "cancelled", "deleted", "declined", "inactive", "removed", "terminated", "waived"
        "waived"
      when "pending", "needs_review", "review_required"
        "pending"
      else
        dependent&.enrollment_status || "pending"
      end
    end

    def dependent_eligibility_status(payload, dependent)
      status = payload.fetch("eligibility_status", nil).presence ||
        payload.fetch("verification_status", nil).presence ||
        payload.fetch("status", nil).presence
      case status.to_s.downcase
      when "active", "accepted", "approved", "eligible", "enrolled", "verified"
        "eligible"
      when "denied", "ineligible", "rejected"
        "ineligible"
      else
        dependent&.eligibility_status || "needs_review"
      end
    end

    def reconcile_payload_only_payroll_deduction(event)
      payload = payroll_deduction_payload(event)
      employee, matched_by = payroll_deduction_employee_match(event, payload)
      unless employee
        return WebhookResourceReconciliationDto.new(
          status: "unmatched",
          resource_type: event.resource_type,
          resource_id: event.resource_id,
          local_record_type: nil,
          local_record_id: nil,
          matched_by: nil,
          applied_changes: [],
          warnings: [ "No local employee matched this Vitable payroll deduction payload." ]
        )
      end

      result = PayrollDeductionRepository.new.sync_employee_deductions(
        employee:,
        remote_deductions: [ payload ],
        source: "vitable_webhook_payload",
        source_event: event,
        reconciled_at: Time.current.iso8601
      )

      WebhookResourceReconciliationDto.new(
        status: "matched",
        resource_type: event.resource_type,
        resource_id: event.resource_id,
        local_record_type: "Employee",
        local_record_id: employee.id,
        matched_by:,
        applied_changes: result.changed_ids.map { |id| "payroll_deductions.#{id}" },
        warnings: []
      )
    end

    def payroll_deduction_payload(event)
      payload = event.payload.to_h.stringify_keys
      resource_payload = %w[data resource object].lazy.filter_map do |key|
        value = payload.fetch(key, nil)
        value.to_h.stringify_keys if value.respond_to?(:to_h)
      end.first || payload

      resource_payload.merge(
        "id" => resource_payload.fetch("id", nil).presence || event.resource_id
      )
    end

    def payroll_deduction_employee_match(event, payload)
      scope = payload_employee_scope(event)
      employee_payload = nested_employee_payload(payload)
      reference_id = payload.fetch("reference_id", nil).presence ||
        employee_payload.fetch("reference_id", nil).presence
      employee = employee_from_local_reference_id(scope, reference_id)
      return [ employee, "reference_id" ] if employee

      remote_employee_id = payload.fetch("employee_id", nil).presence ||
        payload.fetch("member_id", nil).presence ||
        employee_payload.fetch("id", nil).presence
      if remote_employee_id.present?
        employee = scope.find_by(vitable_id: remote_employee_id) ||
          scope.detect { |candidate| candidate.metadata.to_h.stringify_keys.fetch("vitable_member_id", nil) == remote_employee_id }
        return [ employee, "remote_employee_id" ] if employee
      end

      email = payload.fetch("email", nil).presence || employee_payload.fetch("email", nil).presence
      if email.present?
        employee = employee_by_email(scope, email)
        return [ employee, "email" ] if employee
      end

      [ nil, nil ]
    end

    def nested_employee_payload(payload)
      employee = payload.fetch("employee", {})
      return employee.to_h.stringify_keys if employee.respond_to?(:to_h)

      {}
    end

    def employee_from_local_reference_id(scope, reference_id)
      value = reference_id.to_s
      return unless value.match?(/\Amusto_employee_\d+\z/)

      scope.find_by(id: value.delete_prefix("musto_employee_").to_i)
    end

    def employee_by_email(scope, email)
      normalized = email.to_s.downcase.presence
      return if normalized.blank?

      matches = scope.select { |employee| employee.email.to_s.downcase == normalized }
      matches.one? ? matches.first : nil
    end

    def payload_employee_scope(event)
      organization = event.integration_connection&.organization
      employers = Employer.where(organization_id: organization&.id)
      Employee.where(employer_id: employers.select(:id))
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
      employer_reconciliation = snapshot.fetch("employer_reconciliation", {}).to_h
      group_reconciliation = snapshot.fetch("group_reconciliation", {}).to_h
      plan_reconciliation = snapshot.fetch("plan_reconciliation", [])
      employee_reconciliation = snapshot.fetch("employee_reconciliation", {}).to_h
      enrollment_reconciliation = snapshot.fetch("enrollment_reconciliation", {}).to_h
      employee_deduction_sync = employee_reconciliation.fetch("deduction_sync", {}).to_h
      employee_lifecycle = employee_reconciliation.fetch("lifecycle_reconciliation", {}).to_h
      deduction_sync = enrollment_reconciliation.fetch("deduction_sync", {}).to_h

      {
        "remote_employer_count" => snapshot.fetch("employers", []).count,
        "mapped_employer_count" => employer_reconciliation.fetch("matched_count", 0),
        "unmatched_remote_employer_count" => employer_reconciliation.fetch("unmatched_count", 0),
        "conflicting_remote_employer_count" => employer_reconciliation.fetch("conflict_count", 0),
        "remote_group_count" => snapshot.fetch("groups", []).count,
        "mapped_group_count" => group_reconciliation.fetch("matched_count", 0),
        "unmatched_remote_group_count" => group_reconciliation.fetch("unmatched_count", 0),
        "conflicting_remote_group_count" => group_reconciliation.fetch("conflict_count", 0),
        "remote_plan_count" => snapshot.fetch("plans", []).count,
        "mapped_plan_count" => plan_reconciliation.sum { |entry| entry.to_h.fetch("mapped_plan_count", 0) },
        "unmatched_remote_plan_count" => plan_reconciliation.sum { |entry| entry.to_h.fetch("unmatched_remote_count", 0) },
        "unmatched_local_plan_count" => plan_reconciliation.sum { |entry| entry.to_h.fetch("unmatched_local_count", 0) },
        "ambiguous_remote_plan_count" => plan_reconciliation.sum { |entry| entry.to_h.fetch("ambiguous_remote_count", 0) },
        "remote_webhook_event_count" => snapshot.fetch("webhook_events", []).count,
        "recovered_webhook_event_count" => snapshot.fetch("webhook_event_recovery", {}).to_h.fetch("processed_count", 0),
        "failed_webhook_recovery_count" => snapshot.fetch("webhook_event_recovery", {}).to_h.fetch("failed_count", 0),
        "skipped_webhook_recovery_count" => snapshot.fetch("webhook_event_recovery", {}).to_h.fetch("skipped_count", 0),
        "remote_employee_count" => snapshot.fetch("remote_employee_rosters", []).sum { |entry| entry.to_h.fetch("employees", []).count },
        "mapped_employee_count" => employee_reconciliation.fetch("matched_count", 0),
        "unmatched_remote_employee_count" => employee_reconciliation.fetch("unmatched_count", 0),
        "remote_employee_deduction_changed_count" => employee_deduction_sync.fetch("created_count", 0) + employee_deduction_sync.fetch("updated_count", 0),
        "inactive_employee_enrollment_count" => employee_lifecycle.fetch("inactive_enrollment_count", 0),
        "inactive_employee_payroll_deduction_count" => employee_lifecycle.fetch("inactive_payroll_deduction_count", 0),
        "remote_employee_enrollment_count" => snapshot.fetch("employee_enrollments", []).sum { |entry| entry.fetch("enrollments", []).count },
        "reconciled_enrollment_count" => enrollment_reconciliation.fetch("matched_count", 0),
        "created_enrollment_count" => enrollment_reconciliation.fetch("created_count", 0),
        "updated_enrollment_count" => enrollment_reconciliation.fetch("updated_count", 0),
        "enrollment_missing_plan_count" => enrollment_reconciliation.fetch("missing_plan_count", 0),
        "enrollment_deduction_changed_count" => deduction_sync.fetch("created_count", 0) + deduction_sync.fetch("updated_count", 0),
        "imported_webhook_event_count" => webhook_ingestion.fetch("created_count", 0),
        "existing_webhook_event_count" => webhook_ingestion.fetch("existing_count", 0)
      }
    end

    def webhook_recovery_counts(recovery)
      recovery = recovery.to_h
      {
        "webhook_recovery_candidate_count" => recovery.fetch("candidate_count", 0),
        "recovered_webhook_event_count" => recovery.fetch("processed_count", 0),
        "failed_webhook_recovery_count" => recovery.fetch("failed_count", 0),
        "skipped_webhook_recovery_count" => recovery.fetch("skipped_count", 0)
      }
    end

    def ingest_remote_webhook_events(connection, remote_events, refreshed_at:)
      created_event_ids = []
      existing_event_ids = []
      skipped_events = []
      expected_organization_id = connection.organization.external_id.presence

      remote_events.each do |remote_event|
        dto = RemoteWebhookEventDto.from_remote_event(remote_event)

        if dto.blank?
          skipped_events << skipped_remote_webhook_event(remote_event, reason: "incomplete_event")
          next
        end

        if remote_webhook_event_organization_mismatch?(dto, expected_organization_id)
          skipped_events << skipped_remote_webhook_event(
            remote_event,
            reason: "organization_mismatch",
            organization_id: dto.organization_id,
            expected_organization_id:
          )
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
        "skipped_count" => skipped_events.count,
        "created_event_ids" => created_event_ids,
        "existing_event_ids" => existing_event_ids,
        "skipped_event_ids" => skipped_events.map { |event| event.fetch("event_id") },
        "skipped_events" => skipped_events,
        "refreshed_at" => refreshed_at.iso8601
      }
    end

    def remote_webhook_event_organization_mismatch?(dto, expected_organization_id)
      expected_organization_id.present? && dto.organization_id.present? && dto.organization_id != expected_organization_id
    end

    def skipped_remote_webhook_event(remote_event, reason:, organization_id: nil, expected_organization_id: nil)
      {
        "event_id" => RemoteWebhookEventDto.remote_event_id(remote_event),
        "reason" => reason,
        "organization_id" => organization_id,
        "expected_organization_id" => expected_organization_id
      }.compact
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

      PayloadRedactor.redact(serialized.deep_stringify_keys)
    end
  end
end
