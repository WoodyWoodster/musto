module Vitable
  class RefreshApiSnapshotCommand < ApplicationCommand
    MAX_RECOVERED_WEBHOOK_EVENTS = 25
    WEBHOOK_EVENT_LOOKBACK = 5.minutes

    def initialize(dto:, repository: IntegrationRepository.new, gateway_class: ClientGateway)
      @dto = dto
      @repository = repository
      @gateway_class = gateway_class
    end

    def call
      snapshot_trace = {}
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

      snapshot = build_snapshot(connection, trace: snapshot_trace)
      sync_run = @repository.succeed_api_snapshot_run(connection, sync_run, snapshot)
      recovery = recover_webhook_events(connection, sync_run)
      sync_run = @repository.record_api_snapshot_webhook_recovery(connection, sync_run, recovery)
      success(record: sync_run, value: connection.reload.metadata.fetch("api_snapshot"))
    rescue VitableConnect::Errors::APIError => e
      @repository.fail_api_snapshot_run(connection, sync_run, e, trace: snapshot_trace)
      failure(record: sync_run, errors: PayloadRedactor.error_with_class(e))
    rescue ArgumentError => e
      @repository.fail_api_snapshot_run(connection, sync_run, e, trace: snapshot_trace)
      failure(record: sync_run, errors: PayloadRedactor.error_message(e))
    rescue ActiveRecord::RecordInvalid => e
      failure(record: e.record, errors: e.record.errors.full_messages)
    end

    private

    def build_snapshot(connection, trace:)
      gateway = @gateway_class.new(connection)
      snapshot_refreshed_at = Time.current
      refreshed_at = snapshot_refreshed_at.iso8601
      employers = list_snapshot_page(trace, step: "employers", response_label: "Vitable employer list response") { gateway.list_all_employers }
      groups = list_snapshot_page(trace, step: "groups", response_label: "Vitable group list response") { gateway.list_all_groups }
      plans = list_snapshot_page(trace, step: "plans", response_label: "Vitable plan list response") { gateway.list_all_plans }
      employer_details = remote_employer_details(gateway, connection, trace:)
      group_details = remote_group_details(gateway, connection, groups, trace:)
      employer_reconciliation = RemoteEmployerSnapshotRepository.new(connection:).reconcile_snapshot(
        remote_employers: employer_reconciliation_snapshots(employers, employer_details),
        source: "vitable_api_snapshot",
        refreshed_at:
      )
      group_reconciliation = RemoteGroupSnapshotRepository.new(connection:).reconcile_snapshot(
        remote_groups: group_reconciliation_snapshots(groups, group_details),
        source: "vitable_api_snapshot",
        refreshed_at:
      )
      plan_reconciliation = plan_reconciliation_snapshots(connection, plans, refreshed_at:)
      eligibility_policies = eligibility_policy_snapshots(gateway, connection, trace:)
      eligibility_policy_reconciliation = EligibilityPolicySnapshotRepository.new(connection:).reconcile_snapshot(
        snapshot_entries: eligibility_policies,
        source: "vitable_api_snapshot",
        refreshed_at:
      )
      remote_employee_rosters = remote_employee_rosters(gateway, connection, trace:)
      employee_details = remote_employee_details(gateway, remote_employee_rosters, trace:)
      employee_reconciliation = RemoteEmployeeSnapshotRepository.new(connection:).reconcile_snapshot(
        snapshot_entries: employee_reconciliation_snapshots(remote_employee_rosters, employee_details),
        source: "vitable_api_snapshot",
        refreshed_at:
      )
      employee_enrollments = employee_enrollment_snapshot(gateway, connection, trace:)
      enrollment_reconciliation = EnrollmentSnapshotRepository.new(connection:).reconcile_snapshot(
        snapshot_entries: employee_enrollments,
        source: "vitable_api_snapshot",
        refreshed_at:
      )
      webhook_event_query = webhook_event_query(connection, high_water_mark: snapshot_refreshed_at)
      webhook_events = list_snapshot_page(
        trace,
        step: "webhook_events",
        response_label: "Vitable webhook event list response"
      ) { gateway.list_all_webhook_events(**webhook_event_query) }

      {
        "requested_by" => @dto.requested_by,
        "refreshed_at" => refreshed_at,
        "employers" => employers,
        "employer_details" => employer_details,
        "employer_reconciliation" => employer_reconciliation.to_metadata,
        "groups" => groups,
        "group_details" => group_details,
        "group_reconciliation" => group_reconciliation.to_metadata,
        "plans" => plans,
        "plan_reconciliation" => plan_reconciliation,
        "eligibility_policies" => eligibility_policies,
        "eligibility_policy_reconciliation" => eligibility_policy_reconciliation.to_metadata,
        "webhook_event_query" => webhook_event_query_metadata(webhook_event_query),
        "webhook_events" => webhook_events,
        "remote_employee_rosters" => remote_employee_rosters,
        "employee_details" => employee_details,
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

    def remote_employer_details(gateway, connection, trace:)
      return [] unless gateway.respond_to?(:retrieve_employer)

      local_remote_employers(connection).map do |employer|
        response_hash = retrieve_snapshot_resource(
          trace,
          step: "employer",
          response_label: "Vitable employer retrieve response",
          resource_id: employer.vitable_id
        ) { gateway.retrieve_employer(employer.vitable_id) }
        dto = RemoteResourceResponseDto
          .from_response(response_hash, resource_type: "employer", resource_id: employer.vitable_id)
          .validate!
        validate_retrieved_employer!(dto.attributes, expected_remote_id: employer.vitable_id)

        {
          "local_employer_id" => employer.id,
          "remote_employer_id" => employer.vitable_id,
          "employer_name" => employer.name,
          "employer" => dto.attributes,
          "response" => response_hash
        }
      rescue VitableConnect::Errors::NotFoundError => e
        {
          "local_employer_id" => employer.id,
          "remote_employer_id" => employer.vitable_id,
          "employer_name" => employer.name,
          "error_class" => e.class.name,
          "error_message" => PayloadRedactor.error_message(e)
        }
      end
    end

    def employer_reconciliation_snapshots(employers, employer_details)
      detail_records_by_id = employer_details.each_with_object({}) do |entry, index|
        employer = entry.to_h.fetch("employer", nil)
        next unless employer.respond_to?(:to_h)

        employer = employer.to_h.stringify_keys
        remote_id = employer.fetch("id", nil).presence
        index[remote_id] = employer if remote_id.present?
      end

      merged = employers.map do |employer|
        employer = employer.to_h.stringify_keys
        remote_id = employer.fetch("id", nil).presence
        detail_records_by_id.delete(remote_id) || employer
      end

      merged + detail_records_by_id.values
    end

    def validate_retrieved_employer!(remote_employer, expected_remote_id:)
      remote_id = remote_employer.to_h.stringify_keys.fetch("id", nil).presence
      raise ArgumentError, "Vitable employer retrieve response did not include a remote employer ID" if remote_id.blank?
      return if remote_id == expected_remote_id

      raise ArgumentError, "Vitable employer retrieve response returned remote employer ID #{remote_id}, expected #{expected_remote_id}"
    end

    def remote_group_details(gateway, connection, groups, trace:)
      return [] unless gateway.respond_to?(:retrieve_group)

      remote_group_ids(groups, connection).map do |group_id|
        response_hash = retrieve_snapshot_resource(
          trace,
          step: "group",
          response_label: "Vitable group retrieve response",
          resource_id: group_id
        ) { gateway.retrieve_group(group_id) }
        dto = RemoteResourceResponseDto
          .from_response(response_hash, resource_type: "group", resource_id: group_id)
          .validate!
        validate_retrieved_group!(dto.attributes, expected_remote_id: group_id)

        {
          "remote_group_id" => group_id,
          "group" => dto.attributes,
          "response" => response_hash
        }
      rescue VitableConnect::Errors::NotFoundError => e
        {
          "remote_group_id" => group_id,
          "error_class" => e.class.name,
          "error_message" => PayloadRedactor.error_message(e)
        }
      end
    end

    def group_reconciliation_snapshots(groups, group_details)
      detail_records_by_id = group_details.each_with_object({}) do |entry, index|
        group = entry.to_h.fetch("group", nil)
        next unless group.respond_to?(:to_h)

        group = group.to_h.stringify_keys
        remote_id = group.fetch("id", nil).presence
        index[remote_id] = group if remote_id.present?
      end

      merged = groups.map do |group|
        group = group.to_h.stringify_keys
        remote_id = group.fetch("id", nil).presence
        detail_records_by_id.delete(remote_id) || group
      end

      merged + detail_records_by_id.values
    end

    def remote_group_ids(groups, connection)
      (
        groups.filter_map { |group| group.to_h.stringify_keys.fetch("id", nil).presence } +
        local_group_ids(connection)
      ).uniq
    end

    def local_group_ids(connection)
      local_employers(connection).filter_map do |employer|
        employer.settings.to_h.stringify_keys.fetch(CareGroupRepository::GROUP_ID_KEY, nil).presence
      end
    end

    def validate_retrieved_group!(remote_group, expected_remote_id:)
      remote_id = remote_group.to_h.stringify_keys.fetch("id", nil).presence
      raise ArgumentError, "Vitable group retrieve response did not include a remote group ID" if remote_id.blank?
      return if remote_id == expected_remote_id

      raise ArgumentError, "Vitable group retrieve response returned remote group ID #{remote_id}, expected #{expected_remote_id}"
    end

    def remote_employee_rosters(gateway, connection, trace:)
      local_remote_employers(connection).map do |employer|
        {
          "local_employer_id" => employer.id,
          "remote_employer_id" => employer.vitable_id,
          "employer_name" => employer.name,
          "employees" => list_snapshot_page(
            trace,
            step: "employer_employees",
            response_label: "Vitable employer employee list response",
            resource_id: employer.vitable_id
          ) { gateway.list_all_employer_employees(employer.vitable_id) }
        }
      rescue VitableConnect::Errors::NotFoundError => e
        {
          "local_employer_id" => employer.id,
          "remote_employer_id" => employer.vitable_id,
          "employer_name" => employer.name,
          "employees" => [],
          "error_class" => e.class.name,
          "error_message" => PayloadRedactor.error_message(e)
        }
      end
    end

    def remote_employee_details(gateway, remote_employee_rosters, trace:)
      return [] unless gateway.respond_to?(:retrieve_employee)

      remote_employee_ids(remote_employee_rosters).map do |employee_id|
        response_hash = retrieve_snapshot_resource(
          trace,
          step: "employee",
          response_label: "Vitable employee retrieve response",
          resource_id: employee_id
        ) { gateway.retrieve_employee(employee_id) }
        dto = RemoteResourceResponseDto
          .from_response(response_hash, resource_type: "employee", resource_id: employee_id)
          .validate!
        validate_retrieved_employee!(dto.attributes, expected_remote_id: employee_id)

        {
          "remote_employee_id" => employee_id,
          "employee" => dto.attributes,
          "response" => response_hash
        }
      rescue VitableConnect::Errors::NotFoundError => e
        {
          "remote_employee_id" => employee_id,
          "error_class" => e.class.name,
          "error_message" => PayloadRedactor.error_message(e)
        }
      end
    end

    def employee_reconciliation_snapshots(remote_employee_rosters, employee_details)
      detail_records_by_id = employee_details.each_with_object({}) do |entry, index|
        employee = entry.to_h.fetch("employee", nil)
        next unless employee.respond_to?(:to_h)

        employee = employee.to_h.stringify_keys
        remote_id = employee.fetch("id", nil).presence
        index[remote_id] = employee if remote_id.present?
      end

      remote_employee_rosters.map do |entry|
        entry = entry.to_h.stringify_keys
        employees = entry.fetch("employees", []).map do |employee|
          employee = employee.to_h.stringify_keys
          remote_id = employee.fetch("id", nil).presence
          detail = detail_records_by_id.delete(remote_id)
          detail.present? ? employee.merge(detail.compact) : employee
        end

        entry.merge("employees" => employees)
      end
    end

    def remote_employee_ids(remote_employee_rosters)
      remote_employee_rosters.flat_map do |entry|
        entry.to_h.fetch("employees", []).filter_map do |employee|
          employee.to_h.stringify_keys.fetch("id", nil).presence
        end
      end.uniq
    end

    def validate_retrieved_employee!(remote_employee, expected_remote_id:)
      remote_id = remote_employee.to_h.stringify_keys.fetch("id", nil).presence
      raise ArgumentError, "Vitable employee retrieve response did not include a remote employee ID" if remote_id.blank?
      return if remote_id == expected_remote_id

      raise ArgumentError, "Vitable employee retrieve response returned remote employee ID #{remote_id}, expected #{expected_remote_id}"
    end

    def eligibility_policy_snapshots(gateway, connection, trace:)
      local_employers(connection).filter_map do |employer|
        policy_id = eligibility_policy_id_for(employer)
        next if policy_id.blank?

        remote_employer_id = eligibility_policy_remote_employer_id_for(employer)
        response_hash = retrieve_snapshot_resource(
          trace,
          step: "eligibility_policy",
          response_label: "Vitable eligibility policy response",
          resource_id: policy_id
        ) { gateway.retrieve_eligibility_policy(policy_id) }
        RemoteEligibilityPolicyResponseDto
          .from_hash(response_hash)
          .validate!(expected_employer_id: remote_employer_id)

        {
          "local_employer_id" => employer.id,
          "remote_employer_id" => remote_employer_id,
          "remote_policy_id" => policy_id,
          "employer_name" => employer.name,
          "policy" => response_hash
        }.compact
      rescue VitableConnect::Errors::NotFoundError => e
        {
          "local_employer_id" => employer.id,
          "remote_employer_id" => remote_employer_id,
          "remote_policy_id" => policy_id,
          "employer_name" => employer.name,
          "error_class" => e.class.name,
          "error_message" => PayloadRedactor.error_message(e)
        }.compact
      end
    end

    def employee_enrollment_snapshot(gateway, connection, trace:)
      local_remote_employees(connection).map do |employee|
        {
          "local_employee_id" => employee.id,
          "remote_employee_id" => employee.vitable_id,
          "employee_name" => employee.full_name,
          "email" => employee.email,
          "enrollments" => list_snapshot_page(
            trace,
            step: "employee_enrollments",
            response_label: "Vitable employee enrollment list response",
            resource_id: employee.vitable_id
          ) { gateway.list_all_employee_enrollments(employee.vitable_id) }
        }
      rescue VitableConnect::Errors::NotFoundError => e
        {
          "local_employee_id" => employee.id,
          "remote_employee_id" => employee.vitable_id,
          "employee_name" => employee.full_name,
          "email" => employee.email,
          "error_class" => e.class.name,
          "error_message" => PayloadRedactor.error_message(e)
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

    def webhook_event_query(connection, high_water_mark:)
      previous_refreshed_at = previous_api_snapshot_refreshed_at(connection)
      query = { created_before: high_water_mark }
      return query unless previous_refreshed_at

      query.merge(created_after: previous_refreshed_at - WEBHOOK_EVENT_LOOKBACK)
    end

    def previous_api_snapshot_refreshed_at(connection)
      refreshed_at = connection.metadata.to_h.dig("api_snapshot", "refreshed_at")
      return if refreshed_at.blank?

      Time.iso8601(refreshed_at.to_s)
    rescue ArgumentError
      nil
    end

    def eligibility_policy_id_for(employer)
      profile = employer.settings.to_h.fetch("vitable_eligibility_policy", {}).to_h.stringify_keys
      profile.fetch("remote_policy_id", nil).presence ||
        RemoteEligibilityPolicyResponseDto.from_hash(profile.fetch("remote_response", {})).remote_policy_id
    end

    def eligibility_policy_remote_employer_id_for(employer)
      profile = employer.settings.to_h.fetch("vitable_eligibility_policy", {}).to_h.stringify_keys

      profile.fetch("remote_employer_id", nil).presence || employer.vitable_id.presence
    end

    def webhook_event_query_metadata(query)
      query.transform_values do |value|
        value.respond_to?(:iso8601) ? value.iso8601 : value.to_s
      end.deep_stringify_keys
    end

    def list_snapshot_page(trace, step:, response_label:, resource_id: nil)
      response = yield
      response_hash = serialize_response(response)
      trace.replace(
        {
          "last_step" => step,
          "last_resource_id" => resource_id,
          "last_response" => response_hash,
          "last_fetched_at" => Time.current.iso8601
        }.compact
      )

      RemoteCollectionResponseDto
        .from_response(response_hash, response_label:)
        .records
    end

    def retrieve_snapshot_resource(trace, step:, response_label:, resource_id:)
      response = yield
      response_hash = serialize_response(response)
      trace.replace(
        {
          "last_step" => step,
          "last_resource_id" => resource_id,
          "last_response" => response_hash,
          "last_fetched_at" => Time.current.iso8601
        }.compact
      )

      RemoteResourceResponseDto
        .from_response(response_hash, resource_type: step, resource_id:)
        .validate!
      response_hash
    rescue ArgumentError
      raise ArgumentError, "#{response_label} for #{resource_id} did not include resource attributes"
    end

    def page_data(response, response_label:)
      RemoteCollectionResponseDto
        .from_response(serialize_response(response), response_label:)
        .records
    end

    def serialize_response(response)
      serialized =
        if response.blank?
          {}
        elsif response.respond_to?(:deep_to_h)
          response.deep_to_h
        elsif response.respond_to?(:to_h)
          response.to_h
        else
          { "value" => response.to_s }
        end

      PayloadRedactor.redact(serialized.deep_stringify_keys)
    end
  end
end
