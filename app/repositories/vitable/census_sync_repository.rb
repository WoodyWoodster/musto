module Vitable
  class CensusSyncRepository < ApplicationRepository
    MAX_EMPLOYEES = 5_000
    CENSUS_OPERATIONS = %w[census_manifest census_sync].freeze

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

    def latest_manifest
      @employer&.settings.to_h.fetch("vitable_census_sync_batch", nil)
    end

    def sync_runs(limit: 12)
      return SyncRun.none unless connection

      connection.sync_runs.where(operation: CENSUS_OPERATIONS).recent_first.limit(limit)
    end

    def request_logs(limit: 12)
      return ApiRequestLog.none unless connection

      connection.api_request_logs.where(operation: "employer.census_sync").recent_first.limit(limit)
    end

    def generate_manifest(requested_by:)
      roster = employees.to_a
      lines = []
      holdbacks = []

      roster.each_with_index do |employee, index|
        if index >= MAX_EMPLOYEES
          holdbacks << holdback_for(employee, "batch_limit", "Vitable census sync accepts up to #{MAX_EMPLOYEES} employees per request.")
          next
        end

        missing_fields = missing_required_fields(employee)
        if missing_fields.any?
          holdbacks << holdback_for(employee, "missing_required_fields", "Missing #{missing_fields.to_sentence}.")
          next
        end

        lines << line_for(employee)
      end

      manifest = {
        "batch_id" => "vitable_census_#{@employer.id}_#{Time.current.to_i}",
        "generated_at" => Time.current.iso8601,
        "requested_by" => requested_by,
        "employer_id" => @employer.id,
        "remote_employer_id" => @employer.vitable_id,
        "endpoint" => "/v1/employers/:employer_id/census-sync",
        "status" => manifest_status(lines, holdbacks),
        "limits" => {
          "max_employees" => MAX_EMPLOYEES,
          "requested_employee_count" => roster.count
        },
        "totals" => {
          "employee_count" => roster.count,
          "ready_count" => lines.count,
          "holdback_count" => holdbacks.count,
          "remote_pending_count" => lines.count { |line| line.fetch("remote_employee_id").blank? }
        },
        "employees" => lines,
        "holdbacks" => holdbacks,
        "api_payload" => {
          "employer_id" => @employer.vitable_id,
          "employees" => lines.map { |line| line.fetch("api_payload") }
        }
      }

      @employer.update!(settings: @employer.settings.to_h.merge("vitable_census_sync_batch" => manifest))
      manifest
    end

    def create_sync_run(manifest:, requested_by:)
      connection.sync_runs.create!(
        resource_type: "employer",
        operation: "census_sync",
        status: "running",
        started_at: Time.current,
        stats: sync_stats(manifest:, requested_by:)
      )
    end

    def mark_sync_blocked(sync_run, message)
      sync_run.update!(
        status: "blocked",
        completed_at: Time.current,
        error_message: message,
        stats: sync_run.stats.to_h.merge("blocked_reason" => message)
      )
      sync_run
    end

    def mark_sync_needs_credentials(sync_run)
      message = "#{connection.api_key_reference} is not configured"
      sync_run.update!(
        status: "needs_credentials",
        completed_at: Time.current,
        error_message: message,
        stats: sync_run.stats.to_h.merge("blocked_reason" => message)
      )
      sync_run
    end

    def mark_sync_succeeded(sync_run, response)
      response_hash = serialize_response(response)
      sync_run.update!(
        status: "succeeded",
        completed_at: Time.current,
        error_message: nil,
        stats: sync_run.stats.to_h.merge(
          "remote_response" => response_hash,
          "remote_accepted_at" => response_hash.dig("data", "accepted_at"),
          "remote_employer_id" => response_hash.dig("data", "employer_id") || @employer.vitable_id
        )
      )
      sync_run
    end

    def mark_sync_failed(sync_run, error)
      sync_run&.update!(
        status: "failed",
        completed_at: Time.current,
        error_message: error.message,
        stats: sync_run.stats.to_h.merge("error_class" => error.class.name)
      )
      sync_run
    end

    private

    def manifest_status(lines, holdbacks)
      return "blocked" if lines.empty?
      return "needs_review" if @employer.vitable_id.blank? || holdbacks.any?

      "ready"
    end

    def missing_required_fields(employee)
      missing = []
      missing << "date of birth" if employee.date_of_birth.blank?
      missing << "phone" if phone_for(employee).blank?
      missing << "email" if employee.email.blank?
      missing << "first name" if employee.first_name.blank?
      missing << "last name" if employee.last_name.blank?
      missing
    end

    def line_for(employee)
      payload = api_payload_for(employee)

      {
        "employee_id" => employee.id,
        "employee_name" => employee.full_name,
        "email" => employee.email,
        "phone" => phone_for(employee),
        "date_of_birth" => employee.date_of_birth.iso8601,
        "start_date" => employee.start_on&.iso8601,
        "department_name" => employee.department&.name || "Unassigned",
        "location_name" => employee.work_location&.name || "No location",
        "pay_type" => employee.pay_type,
        "compensation_type" => payload.fetch("compensation_type"),
        "employee_class" => payload.fetch("employee_class"),
        "reference_id" => payload.fetch("reference_id"),
        "remote_employee_id" => employee.vitable_id,
        "enrollment_count" => employee.enrollments.count,
        "status" => employee.vitable_id.present? ? "synced" : "remote_pending",
        "readiness_status" => "ready",
        "readiness_reason" => "Ready for Vitable census sync",
        "api_payload" => payload
      }
    end

    def holdback_for(employee, reason_code, reason)
      {
        "employee_id" => employee.id,
        "employee_name" => employee.full_name,
        "email" => employee.email,
        "department_name" => employee.department&.name || "Unassigned",
        "location_name" => employee.work_location&.name || "No location",
        "status" => "blocked",
        "reason_code" => reason_code,
        "reason" => reason
      }
    end

    def api_payload_for(employee)
      {
        "reference_id" => "musto_employee_#{employee.id}",
        "first_name" => employee.first_name,
        "last_name" => employee.last_name,
        "email" => employee.email,
        "phone" => phone_for(employee),
        "date_of_birth" => employee.date_of_birth.iso8601,
        "start_date" => employee.start_on&.iso8601,
        "compensation_type" => employee.pay_type == "hourly" ? "Hourly" : "Salary",
        "employee_class" => employee.pay_type == "hourly" ? "Part Time" : "Full Time",
        "address" => address_for(employee)
      }.compact
    end

    def address_for(employee)
      location = employee.work_location
      return unless location
      return if [ location.address_line1, location.city, location.state, location.postal_code ].any?(&:blank?)

      {
        "address_line_1" => location.address_line1,
        "city" => location.city,
        "state" => location.state,
        "zipcode" => location.postal_code
      }
    end

    def phone_for(employee)
      metadata = employee.metadata.to_h.stringify_keys
      metadata["phone"].presence || metadata["phone_number"].presence || metadata["mobile_phone"].presence
    end

    def sync_stats(manifest:, requested_by:)
      totals = manifest.fetch("totals", {})

      {
        "batch_id" => manifest.fetch("batch_id"),
        "requested_by" => requested_by,
        "resource_id" => @employer.vitable_id.presence || "local_employer_#{@employer.id}",
        "ready_count" => totals.fetch("ready_count", 0),
        "holdback_count" => totals.fetch("holdback_count", 0),
        "remote_pending_count" => totals.fetch("remote_pending_count", 0),
        "endpoint" => manifest.fetch("endpoint"),
        "payload" => manifest.fetch("api_payload", {})
      }
    end

    def serialize_response(response)
      return {} if response.blank?
      return response.deep_to_h.deep_stringify_keys if response.respond_to?(:deep_to_h)
      return response.to_h.deep_stringify_keys if response.respond_to?(:to_h)

      { "value" => response.to_s }
    end
  end
end
