module Vitable
  class CareGroupRepository < ApplicationRepository
    GROUP_PACKET_KEY = "vitable_care_group_packet"
    MEMBER_MANIFEST_KEY = "vitable_care_member_sync_manifest"
    GROUP_ID_KEY = "vitable_care_group_id"
    MEMBER_SYNC_REQUEST_KEY = "vitable_care_member_sync_last_request"
    MAX_MEMBERS = 5_000
    CARE_OPERATIONS = %w[care_group_upsert care_member_sync_submit care_member_sync_refresh].freeze
    REQUEST_OPERATIONS = %w[group.create group.update group.retrieve group.list group.member_sync.submit group.member_sync.retrieve].freeze

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

      roster.each_with_index do |employee, index|
        if index >= MAX_MEMBERS
          holdbacks << member_holdback_for(employee, nil, "batch_limit", "Vitable group member sync accepts up to #{MAX_MEMBERS} members per request.")
          next
        end

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
          "max_members" => MAX_MEMBERS,
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
      group_id = extract_group_id(response_hash).presence || remote_group_id
      synced_at = Time.current.iso8601
      merge_settings(
        GROUP_ID_KEY => group_id,
        GROUP_PACKET_KEY => packet,
        "vitable_care_group_last_sync" => {
          "synced_at" => synced_at,
          "operation" => sync_run.operation,
          "packet_id" => packet.fetch("packet_id"),
          "mode" => packet.fetch("mode"),
          "remote_group_id" => group_id
        }
      )

      sync_run.update!(
        status: "succeeded",
        completed_at: Time.current,
        error_message: nil,
        stats: sync_run.stats.to_h.merge(
          "remote_response" => response_hash,
          "remote_group_id" => group_id,
          "remote_synced_at" => synced_at
        )
      )
      sync_run
    end

    def mark_member_sync_succeeded(sync_run, response)
      response_hash = serialize_response(response)
      data = response_hash.fetch("data", response_hash)
      accepted_at = data.fetch("accepted_at", nil)
      request_id = data.fetch("request_id", nil)
      group_id = data.fetch("group_id", remote_group_id)

      merge_settings(
        MEMBER_SYNC_REQUEST_KEY => {
          "request_id" => request_id,
          "group_id" => group_id,
          "accepted_at" => accepted_at,
          "completed_at" => data.fetch("completed_at", nil),
          "results" => data.fetch("results", nil),
          "status" => data.fetch("completed_at", nil).present? ? "complete" : "processing",
          "refreshed_at" => Time.current.iso8601
        }.compact
      )

      sync_run.update!(
        status: "succeeded",
        completed_at: Time.current,
        error_message: nil,
        stats: sync_run.stats.to_h.merge(
          "remote_response" => response_hash,
          "remote_group_id" => group_id,
          "remote_request_id" => request_id,
          "remote_accepted_at" => accepted_at
        )
      )
      sync_run
    end

    def mark_member_sync_refresh_succeeded(sync_run, response)
      response_hash = serialize_response(response)
      data = response_hash.fetch("data", response_hash)
      previous = latest_member_sync_request.to_h

      merge_settings(
        MEMBER_SYNC_REQUEST_KEY => previous.merge(
          "request_id" => data.fetch("request_id", previous.fetch("request_id", nil)),
          "group_id" => data.fetch("group_id", previous.fetch("group_id", nil)),
          "accepted_at" => data.fetch("accepted_at", previous.fetch("accepted_at", nil)),
          "completed_at" => data.fetch("completed_at", nil),
          "results" => data.fetch("results", nil),
          "status" => data.fetch("completed_at", nil).present? ? "complete" : "processing",
          "refreshed_at" => Time.current.iso8601
        ).compact
      )

      sync_run.update!(
        status: "succeeded",
        completed_at: Time.current,
        error_message: nil,
        stats: sync_run.stats.to_h.merge(
          "remote_response" => response_hash,
          "completed_at" => data.fetch("completed_at", nil),
          "failure_count" => data.dig("results", "failures").to_a.count
        )
      )
      sync_run
    end

    def mark_failed(sync_run, error)
      sync_run&.update!(
        status: "failed",
        completed_at: Time.current,
        error_message: error.message,
        stats: sync_run.stats.to_h.merge("error_class" => error.class.name)
      )
      sync_run
    end

    private

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
        "first_name" => employee.first_name,
        "last_name" => employee.last_name,
        "email" => employee.email,
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
        "email" => employee.email,
        "phone" => payload.fetch("phone"),
        "date_of_birth" => payload.fetch("date_of_birth"),
        "department_name" => employee.department&.name || "Unassigned",
        "location_name" => employee.work_location&.name || "No location",
        "plan_name" => enrollment.benefit_plan.name,
        "plan_id" => payload.fetch("plan_id"),
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
      {
        "address_line_1" => address.to_h.fetch("address_line_1", nil),
        "city" => address.to_h.fetch("city", nil),
        "state" => address.to_h.fetch("state", nil),
        "zipcode" => address.to_h.fetch("zipcode", nil)
      }.filter_map { |field, value| field if value.blank? }
    end

    def address_for(employee)
      location = employee.work_location
      return {} unless location

      {
        "address_line_1" => location.address_line1,
        "city" => location.city,
        "state" => location.state,
        "zipcode" => location.postal_code
      }.compact
    end

    def phone_for(employee)
      metadata = employee.metadata.to_h.stringify_keys
      metadata["phone"].presence || metadata["phone_number"].presence || metadata["mobile_phone"].presence
    end

    def plan_id_for(plan)
      return if plan.blank?

      plan.vitable_id.presence ||
        plan.metadata.to_h.stringify_keys.fetch("vitable_plan_id", nil).presence ||
        @employer.settings.to_h.stringify_keys.fetch("vitable_care_plan_id", nil).presence
    end

    def serialize_response(response)
      return {} if response.blank?
      return response.deep_to_h.deep_stringify_keys if response.respond_to?(:deep_to_h)
      return response.to_h.deep_stringify_keys if response.respond_to?(:to_h)

      { "value" => response.to_s }
    end

    def extract_group_id(response_hash)
      response_hash.dig("data", "id") ||
        response_hash.dig("data", "group", "id") ||
        response_hash.fetch("id", nil)
    end

    def merge_settings(attributes)
      @employer.update!(settings: @employer.settings.to_h.merge(attributes.compact))
    end
  end
end
