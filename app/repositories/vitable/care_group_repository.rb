module Vitable
  class CareGroupRepository < ApplicationRepository
    GROUP_PACKET_KEY = "vitable_care_group_packet"
    MEMBER_MANIFEST_KEY = "vitable_care_member_sync_manifest"
    GROUP_ID_KEY = "vitable_care_group_id"
    MEMBER_SYNC_REQUEST_KEY = "vitable_care_member_sync_last_request"
    MAX_MEMBERS = 5_000
    CARE_OPERATIONS = %w[care_group_upsert care_member_sync_submit care_member_sync_refresh].freeze
    REQUEST_OPERATIONS = %w[group.create group.update group.retrieve group.list group.member_sync.submit group.member_sync.retrieve].freeze
    VITABLE_ADDRESS_STATES = %w[
      AL AK AZ AR CA CO CT DC DE FL GA HI ID IL IN IA KS KY LA ME MD MA MI MN MS MO MT NE NV NH NJ NM NY NC ND OH OK OR PA RI SC SD TN TX UT VT VA WA WI WV WY
      PR GU AS VI MP MH PW FM AE AA AP
    ].freeze

    def initialize(employer:)
      @employer = employer
    end

    def connection
      @connection ||= vitable_connection_for(@employer&.organization)
    end

    def employees
      return Employee.none unless @employer

      @employer
        .employees
        .active
        .includes(:department, :work_location, enrollments: [ :benefit_plan ])
        .order(:last_name, :first_name)
    end

    def latest_group_packet
      @employer&.settings.to_h.fetch(GROUP_PACKET_KEY, nil)
    end

    def latest_member_manifest
      @employer&.settings.to_h.fetch(MEMBER_MANIFEST_KEY, nil)
    end

    def remote_group_id
      @employer&.settings.to_h.fetch(GROUP_ID_KEY, nil).presence
    end

    def latest_member_sync_request
      @employer&.settings.to_h.fetch(MEMBER_SYNC_REQUEST_KEY, nil)
    end

    def sync_runs(limit: 12)
      return SyncRun.none unless connection

      connection.sync_runs.where(operation: CARE_OPERATIONS).recent_first.limit(limit)
    end

    def request_logs(limit: 12)
      return ApiRequestLog.none unless connection

      connection.api_request_logs.where(operation: REQUEST_OPERATIONS).recent_first.limit(limit)
    end

    def preview_group_packet(requested_by: "preview")
      build_group_packet(requested_by:)
    end

    def generate_group_packet(requested_by:)
      packet = build_group_packet(requested_by:)
      merge_settings(GROUP_PACKET_KEY => packet)
      packet
    end

    def generate_member_manifest(requested_by:)
      roster = employees.to_a
      members = []
      holdbacks = []

      roster.each do |employee|
        enrollment = care_enrollment_for(employee)
        payload = member_payload_for(employee, enrollment)
        missing_fields = missing_member_fields(payload)

        if enrollment.blank?
          holdbacks << member_holdback_for(employee, nil, "missing_care_enrollment", "Employee needs an active care enrollment before group member sync.")
          next
        end

        if missing_fields.any?
          reason_code = missing_fields.include?("plan_id") ? "missing_remote_plan_id" : "missing_required_fields"
          holdbacks << member_holdback_for(employee, enrollment, reason_code, "Missing #{missing_fields.map(&:humanize).to_sentence}.")
          next
        end

        invalid_fields = invalid_member_fields(payload)
        if invalid_fields.any?
          holdbacks << member_holdback_for(employee, enrollment, "invalid_api_contract_fields", "Invalid #{invalid_fields.to_sentence} for Vitable group member sync.")
          next
        end

        if members.count >= max_members
          holdbacks << member_holdback_for(employee, enrollment, "batch_limit", "Vitable group member sync accepts up to #{max_members} members per request.")
          next
        end

        members << member_line_for(employee, enrollment, payload)
      end

      manifest = {
        "manifest_id" => "vitable_care_members_#{@employer.id}_#{Time.current.to_i}",
        "generated_at" => Time.current.iso8601,
        "requested_by" => requested_by,
        "employer_id" => @employer.id,
        "remote_group_id" => remote_group_id,
        "endpoint" => "/v1/groups/:group_id/members/sync",
        "status" => member_manifest_status(members, holdbacks),
        "limits" => {
          "max_members" => max_members,
          "requested_member_count" => roster.count
        },
        "totals" => {
          "employee_count" => roster.count,
          "ready_count" => members.count,
          "holdback_count" => holdbacks.count,
          "remote_plan_missing_count" => holdbacks.count { |holdback| holdback.fetch("reason_code") == "missing_remote_plan_id" }
        },
        "members" => members,
        "holdbacks" => holdbacks,
        "api_payload" => {
          "group_id" => remote_group_id,
          "members" => members.map { |line| line.fetch("api_payload") }
        }
      }

      merge_settings(MEMBER_MANIFEST_KEY => manifest)
      manifest
    end

    def create_group_run(packet:, requested_by:)
      connection.sync_runs.create!(
        resource_type: "group",
        operation: "care_group_upsert",
        status: "running",
        started_at: Time.current,
        stats: {
          "packet_id" => packet.fetch("packet_id"),
          "requested_by" => requested_by,
          "mode" => packet.fetch("mode"),
          "resource_id" => remote_group_id.presence || "local_employer_#{@employer.id}",
          "endpoint" => packet.fetch("endpoint"),
          "payload" => packet.fetch("api_payload")
        }
      )
    end

    def create_member_sync_run(manifest:, requested_by:)
      totals = manifest.fetch("totals", {})

      connection.sync_runs.create!(
        resource_type: "group",
        operation: "care_member_sync_submit",
        status: "running",
        started_at: Time.current,
        stats: {
          "manifest_id" => manifest.fetch("manifest_id"),
          "requested_by" => requested_by,
          "resource_id" => remote_group_id.presence || "care_group_pending",
          "endpoint" => manifest.fetch("endpoint"),
          "ready_count" => totals.fetch("ready_count", 0),
          "holdback_count" => totals.fetch("holdback_count", 0),
          "payload" => manifest.fetch("api_payload", {})
        }
      )
    end

    def create_member_sync_refresh_run(requested_by:)
      connection.sync_runs.create!(
        resource_type: "group",
        operation: "care_member_sync_refresh",
        status: "running",
        started_at: Time.current,
        stats: {
          "requested_by" => requested_by,
          "resource_id" => remote_group_id.presence || "care_group_pending",
          "endpoint" => "/v1/groups/:group_id/members/sync/:request_id",
          "request_id" => latest_member_sync_request.to_h.fetch("request_id", nil)
        }
      )
    end

    def mark_blocked(sync_run, message)
      sync_run.update!(
        status: "blocked",
        completed_at: Time.current,
        error_message: message,
        stats: sync_run.stats.to_h.merge("blocked_reason" => message)
      )
      sync_run
    end

    def mark_needs_credentials(sync_run)
      message = "#{connection.api_key_reference} is not configured"
      sync_run.update!(
        status: "needs_credentials",
        completed_at: Time.current,
        error_message: message,
        stats: sync_run.stats.to_h.merge("blocked_reason" => message)
      )
      sync_run
    end

    def mark_group_succeeded(sync_run, response, packet:)
      response_hash = serialize_response(response)
      dto = RemoteGroupDto.from_hash(response_hash).validate_care_group_response!(
        expected_group_id: packet.fetch("remote_group_id", nil),
        expected_external_reference_id: packet.dig("api_payload", "external_reference_id")
      )

      synced_at = Time.current.iso8601
      merge_settings(
        GROUP_ID_KEY => dto.group_id,
        GROUP_PACKET_KEY => packet,
        "vitable_care_group_last_sync" => {
          "synced_at" => synced_at,
          "operation" => sync_run.operation,
          "packet_id" => packet.fetch("packet_id"),
          "mode" => packet.fetch("mode"),
          "remote_group_id" => dto.group_id
        }
      )

      sync_run.update!(
        status: "succeeded",
        completed_at: Time.current,
        error_message: nil,
        stats: sync_run.stats.to_h.merge(
          "remote_response" => response_hash,
          "remote_group_id" => dto.group_id,
          "remote_synced_at" => synced_at
        )
      )
      sync_run
    end

    def mark_member_sync_succeeded(sync_run, response)
      response_hash = serialize_response(response)
      dto = RemoteCareMemberSyncResponseDto.from_hash(response_hash).validate_submit!(expected_group_id: remote_group_id)
      synced_at = Time.current

      merge_settings(
        MEMBER_SYNC_REQUEST_KEY => dto.to_request_state(refreshed_at: synced_at)
      )

      sync_run.update!(
        status: "succeeded",
        completed_at: Time.current,
        error_message: nil,
        stats: sync_run.stats.to_h.merge(
          "remote_response" => response_hash,
          "remote_group_id" => dto.group_id,
          "remote_request_id" => dto.request_id,
          "remote_accepted_at" => dto.accepted_at
        )
      )
      sync_run
    end

    def mark_member_sync_refresh_succeeded(sync_run, response)
      response_hash = serialize_response(response)
      previous = latest_member_sync_request.to_h
      dto = RemoteCareMemberSyncResponseDto
        .from_hash(response_hash)
        .validate_refresh!(
          expected_group_id: remote_group_id,
          expected_request_id: previous.fetch("request_id", nil)
        )
      data = dto.raw_payload

      results = member_sync_results(data)
      reconciliation = reconcile_member_sync_results(data, results:)

      merge_settings(
        MEMBER_SYNC_REQUEST_KEY => previous.merge(
          dto.to_request_state(refreshed_at: Time.current).merge("reconciliation" => reconciliation.to_h)
        )
      )

      sync_run.update!(
        status: "succeeded",
        completed_at: Time.current,
        error_message: nil,
        stats: sync_run.stats.to_h.merge(
          "remote_response" => response_hash,
          "completed_at" => data.fetch("completed_at", nil),
          "failure_count" => member_sync_failures(results).count,
          "member_reconciliation_status" => reconciliation.status,
          "succeeded_member_count" => reconciliation.succeeded_count,
          "failed_member_count" => reconciliation.failed_count
        )
      )
      sync_run
    end

    def reconcile_member_sync_snapshot(response, refreshed_at: Time.current)
      response_hash = serialize_response(response)
      previous = latest_member_sync_request.to_h.stringify_keys
      expected_group_id = remote_group_id.presence || previous.fetch("group_id", nil).presence
      dto = RemoteCareMemberSyncResponseDto
        .from_hash(response_hash)
        .validate_refresh!(
          expected_group_id:,
          expected_request_id: previous.fetch("request_id", nil)
        )
      data = dto.raw_payload
      results = member_sync_results(data)
      reconciliation = reconcile_member_sync_results(data, results:)
      request_state = previous.merge(
        dto.to_request_state(refreshed_at:).merge(
          "source" => "vitable_api_snapshot",
          "reconciliation" => reconciliation.to_h
        )
      )

      merge_settings(MEMBER_SYNC_REQUEST_KEY => request_state)

      {
        "request_state" => request_state,
        "reconciliation" => reconciliation.to_h,
        "response" => response_hash,
        "status" => request_state.fetch("status", nil),
        "succeeded_member_count" => reconciliation.succeeded_count,
        "failed_member_count" => reconciliation.failed_count
      }
    end

    def mark_failed(sync_run, error, response: nil)
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

    private

    def max_members
      MAX_MEMBERS
    end

    def build_group_packet(requested_by:)
      payload = {
        "external_reference_id" => "musto_care_group_#{@employer.id}",
        "name" => @employer.name
      }.compact
      mode = remote_group_id.present? ? "update" : "create"
      holdbacks = group_holdbacks_for(payload)

      {
        "packet_id" => "vitable_care_group_#{@employer.id}_#{Time.current.to_i}",
        "generated_at" => Time.current.iso8601,
        "requested_by" => requested_by,
        "employer_id" => @employer.id,
        "remote_group_id" => remote_group_id,
        "endpoint" => mode == "create" ? "/v1/groups" : "/v1/groups/:group_id",
        "mode" => mode,
        "status" => holdbacks.any? ? "blocked" : "ready",
        "totals" => {
          "payload_field_count" => payload.values.compact.count,
          "missing_field_count" => holdbacks.count,
          "holdback_count" => holdbacks.count
        },
        "api_payload" => payload,
        "holdbacks" => holdbacks
      }
    end

    def group_holdbacks_for(payload)
      {
        external_reference_id: payload.fetch("external_reference_id", nil),
        name: payload.fetch("name", nil)
      }.filter_map do |field, value|
        next if value.present?

        {
          "field" => field.to_s,
          "status" => "blocked",
          "reason_code" => "missing_required_field",
          "reason" => "#{field.to_s.humanize} is required before creating a Vitable care group."
        }
      end
    end

    def member_manifest_status(members, holdbacks)
      return "blocked" if members.empty?
      return "needs_review" if remote_group_id.blank? || holdbacks.any?

      "ready"
    end

    def care_enrollment_for(employee)
      candidates = employee.enrollments.select { |enrollment| enrollment.status.in?(%w[accepted pending]) }

      candidates.find { |enrollment| enrollment.benefit_plan.category == "direct_primary_care" && enrollment.benefit_plan.carrier == "Vitable" } ||
        candidates.find { |enrollment| enrollment.benefit_plan.category == "direct_primary_care" } ||
        candidates.find { |enrollment| enrollment.benefit_plan.carrier == "Vitable" } ||
        candidates.first
    end

    def member_payload_for(employee, enrollment)
      {
        "reference_id" => "musto_employee_#{employee.id}",
        "first_name" => employee.first_name.to_s.strip,
        "last_name" => employee.last_name.to_s.strip,
        "email" => email_for(employee),
        "phone" => phone_for(employee),
        "date_of_birth" => employee.date_of_birth&.iso8601,
        "plan_id" => plan_id_for(enrollment&.benefit_plan),
        "address" => address_for(employee)
      }.compact
    end

    def member_line_for(employee, enrollment, payload)
      {
        "employee_id" => employee.id,
        "employee_name" => employee.full_name,
        "email" => payload.fetch("email", nil),
        "phone" => payload.fetch("phone"),
        "date_of_birth" => payload.fetch("date_of_birth"),
        "department_name" => employee.department&.name || "Unassigned",
        "location_name" => employee.work_location&.name || "No location",
        "plan_name" => enrollment.benefit_plan.name,
        "plan_id" => payload.fetch("plan_id"),
        "enrollment_id" => enrollment.id,
        "reference_id" => payload.fetch("reference_id"),
        "remote_employee_id" => employee.vitable_id,
        "status" => "ready",
        "readiness_status" => "ready",
        "readiness_reason" => "Ready for Vitable group member sync",
        "api_payload" => payload
      }
    end

    def member_holdback_for(employee, enrollment, reason_code, reason)
      {
        "employee_id" => employee.id,
        "employee_name" => employee.full_name,
        "email" => employee.email,
        "department_name" => employee.department&.name || "Unassigned",
        "location_name" => employee.work_location&.name || "No location",
        "plan_name" => enrollment&.benefit_plan&.name,
        "plan_id" => plan_id_for(enrollment&.benefit_plan),
        "status" => "blocked",
        "reason_code" => reason_code,
        "reason" => reason
      }
    end

    def missing_member_fields(payload)
      missing = []
      missing << "reference_id" if payload.fetch("reference_id", nil).blank?
      missing << "first_name" if payload.fetch("first_name", nil).blank?
      missing << "last_name" if payload.fetch("last_name", nil).blank?
      missing << "phone" if payload.fetch("phone", nil).blank?
      missing << "date_of_birth" if payload.fetch("date_of_birth", nil).blank?
      missing << "plan_id" if payload.fetch("plan_id", nil).blank?
      missing.concat(missing_address_fields(payload.fetch("address", {})))
      missing
    end

    def missing_address_fields(address)
      address = address.respond_to?(:to_h) ? address.to_h : {}
      {
        "address_line_1" => address.fetch("address_line_1", nil),
        "city" => address.fetch("city", nil),
        "state" => address.fetch("state", nil),
        "zipcode" => address.fetch("zipcode", nil)
      }.filter_map { |field, value| field if value.blank? }
    end

    def address_for(employee)
      location = employee.work_location
      return {} unless location

      {
        "address_line_1" => location.address_line1.to_s.strip,
        "city" => location.city.to_s.strip,
        "state" => location.state.to_s.strip.upcase,
        "zipcode" => location.postal_code.to_s.strip
      }.compact
    end

    def invalid_member_fields(payload)
      fields = []
      fields << "email" if payload.fetch("email", nil).present? && !valid_email?(payload.fetch("email"))
      fields << "phone" unless valid_phone?(payload.fetch("phone", nil))

      address = payload.fetch("address", nil)
      address = address.respond_to?(:to_h) ? address.to_h : {}
      if address.present?
        fields << "address state" unless VITABLE_ADDRESS_STATES.include?(address.fetch("state", nil))
        fields << "address ZIP" unless valid_zipcode?(address.fetch("zipcode", nil))
      end

      fields
    end

    def phone_for(employee)
      metadata = employee.metadata.to_h.stringify_keys
      raw = metadata["phone"].presence || metadata["phone_number"].presence || metadata["mobile_phone"].presence
      digits = raw.to_s.gsub(/\D/, "")
      digits = digits.delete_prefix("1") if digits.length == 11 && digits.start_with?("1")
      digits.presence
    end

    def email_for(employee)
      employee.email.to_s.strip.downcase.presence
    end

    def valid_email?(value)
      value.to_s.match?(/\A[^@\s]+@[^@\s]+\.[^@\s]+\z/)
    end

    def valid_phone?(value)
      value.to_s.match?(/\A\d{10}\z/)
    end

    def valid_zipcode?(value)
      value.to_s.match?(/\A\d{5}(-\d{4})?\z/)
    end

    def plan_id_for(plan)
      return if plan.blank?

      plan.vitable_id.presence ||
        plan.metadata.to_h.stringify_keys.fetch("vitable_plan_id", nil).presence ||
        @employer.settings.to_h.stringify_keys.fetch("vitable_care_plan_id", nil).presence
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

    def member_sync_results(data)
      results = data.fetch("results", nil)
      return {} unless results.respond_to?(:to_h)

      results.to_h.stringify_keys
    end

    def member_sync_failures(results)
      Array(results.fetch("failures", [])).map { |failure| failure.to_h.stringify_keys }
    end

    def reconcile_member_sync_results(data, results:)
      manifest = latest_member_manifest.to_h.deep_dup
      submitted_members = manifest.fetch("members", [])
      return empty_member_reconciliation(status: "processing", submitted_count: submitted_members.count) if results.blank?

      failures = member_sync_failures(results)
      failures_by_reference = failures.index_by { |failure| failure.fetch("reference_id", nil) }
      submitted_reference_ids = submitted_members.filter_map { |member| member.to_h.stringify_keys.fetch("reference_id", nil) }
      submitted_failures_by_reference = failures_by_reference.slice(*submitted_reference_ids)
      reconciled_at = Time.current.iso8601
      applied_employee_ids = []
      applied_enrollment_ids = []

      manifest["members"] = submitted_members.map do |member|
        member = member.to_h.stringify_keys
        failure = submitted_failures_by_reference[member.fetch("reference_id", nil)]
        status = failure ? "failed" : "succeeded"
        employee = employee_for_member(member)
        enrollment = enrollment_for_member(member, employee)

        if employee
          apply_member_sync_metadata(employee, member:, data:, failure:, status:, reconciled_at:)
          applied_employee_ids << employee.id
        end

        if enrollment
          apply_member_sync_metadata(enrollment, member:, data:, failure:, status:, reconciled_at:)
          applied_enrollment_ids << enrollment.id
        end

        member.merge(
          "status" => status == "succeeded" ? "synced" : "failed",
          "readiness_status" => status == "succeeded" ? "synced" : "failed",
          "readiness_reason" => failure ? failure.fetch("reason", "Vitable member sync failed.") : "Vitable member sync completed."
        )
      end

      merge_settings(MEMBER_MANIFEST_KEY => manifest)
      failed_count = submitted_failures_by_reference.keys.compact.count
      succeeded_count = [ submitted_members.count - failed_count, 0 ].max

      CareMemberSyncReconciliationDto.new(
        status: "complete",
        submitted_count: submitted_members.count,
        succeeded_count:,
        failed_count:,
        added_group_member_ids: Array(results.fetch("added_group_member_ids", [])),
        removed_group_member_ids: Array(results.fetch("removed_group_member_ids", [])),
        failure_reference_ids: submitted_failures_by_reference.keys.compact,
        applied_employee_ids: applied_employee_ids.uniq,
        applied_enrollment_ids: applied_enrollment_ids.uniq
      )
    end

    def empty_member_reconciliation(status:, submitted_count:)
      CareMemberSyncReconciliationDto.new(
        status:,
        submitted_count:,
        succeeded_count: 0,
        failed_count: 0,
        added_group_member_ids: [],
        removed_group_member_ids: [],
        failure_reference_ids: [],
        applied_employee_ids: [],
        applied_enrollment_ids: []
      )
    end

    def employee_for_member(member)
      employee_id = member.fetch("employee_id", nil)
      employee = @employer.employees.find_by(id: employee_id) if employee_id.present?
      employee || employee_from_reference_id(member.fetch("reference_id", nil))
    end

    def employee_from_reference_id(reference_id)
      value = reference_id.to_s
      return unless value.match?(/\Amusto_employee_\d+\z/)

      @employer.employees.find_by(id: value.delete_prefix("musto_employee_").to_i)
    end

    def enrollment_for_member(member, employee)
      return unless employee

      enrollment_id = member.fetch("enrollment_id", nil)
      enrollment = employee.enrollments.find_by(id: enrollment_id) if enrollment_id.present?
      enrollment || employee.enrollments.includes(:benefit_plan).find { |candidate| plan_id_for(candidate.benefit_plan) == member.fetch("plan_id", nil) }
    end

    def apply_member_sync_metadata(record, member:, data:, failure:, status:, reconciled_at:)
      metadata = record.metadata.to_h.stringify_keys.merge(
        "vitable_care_member_sync_status" => status,
        "vitable_care_member_sync_request_id" => data.fetch("request_id", nil),
        "vitable_care_group_id" => data.fetch("group_id", remote_group_id),
        "vitable_care_member_reference_id" => member.fetch("reference_id", nil),
        "vitable_care_member_plan_id" => member.fetch("plan_id", nil),
        "vitable_care_member_synced_at" => reconciled_at,
        "vitable_care_member_sync_failure" => failure&.slice("operation", "reason", "reference_id")
      )
      metadata.delete("vitable_care_member_sync_failure") unless failure
      record.update!(metadata:)
    end

    def merge_settings(attributes)
      @employer.update!(settings: @employer.settings.to_h.merge(attributes.compact))
    end
  end
end
