module Vitable
  class EmbeddedSessionsRepository < ApplicationRepository
    TOKEN_OPERATION = "embedded_enrollment_token"

    def initialize(employer:, eligibility_repository: EmployeeEligibilityRepository.new)
      @employer = employer
      @eligibility_repository = eligibility_repository
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

    def find_employee(id)
      employees.find(id)
    end

    def latest_packet
      @employer&.settings.to_h.fetch("vitable_embedded_sessions_packet", nil)
    end

    def token_runs(limit: 12)
      return SyncRun.none unless connection

      connection.sync_runs.where(operation: TOKEN_OPERATION).recent_first.limit(limit)
    end

    def request_logs(limit: 12)
      return ApiRequestLog.none unless connection

      connection.api_request_logs.where(operation: "auth.issue_employee_access_token").recent_first.limit(limit)
    end

    def generate_packet(requested_by:)
      lines = []
      holdbacks = []

      session_candidates.each do |employee|
        active_enrollments = enrollment_candidates(employee)
        eligibility_block = enrollment_token_block_reason(employee)

        if eligibility_block.present?
          holdbacks << holdback_for(employee, active_enrollments, "eligibility_terminated", eligibility_block)
          next
        end

        if employee.vitable_id.blank?
          holdbacks << holdback_for(employee, active_enrollments, "remote_employee_id", "Employee needs a Vitable employee ID before a bound enrollment token can be issued.")
          next
        end

        lines << line_for(employee, active_enrollments)
      end

      packet = {
        "packet_id" => "vitable_embedded_sessions_#{@employer.id}_#{Time.current.to_i}",
        "generated_at" => Time.current.iso8601,
        "requested_by" => requested_by,
        "employer_id" => @employer.id,
        "enrollment_widget" => enrollment_widget,
        "status" => packet_status(lines, holdbacks),
        "totals" => {
          "employee_count" => session_candidates.count,
          "ready_count" => lines.count,
          "holdback_count" => holdbacks.count,
          "pending_election_count" => lines.sum { |line| line.fetch("pending_enrollment_count") }
        },
        "token_request" => {
          "grant_type" => "client_credentials",
          "bound_entity_type" => "employee",
          "endpoint" => "/v1/auth/access-tokens",
          "authorization_header" => WidgetLaunchToken::HEADER
        },
        "employees" => lines,
        "holdbacks" => holdbacks
      }

      @employer.update!(settings: @employer.settings.to_h.merge("vitable_embedded_sessions_packet" => packet))
      packet
    end

    def create_token_run(employee:, requested_by:)
      line = line_or_holdback_for(employee)

      connection.sync_runs.create!(
        resource_type: "employee",
        operation: TOKEN_OPERATION,
        status: "running",
        started_at: Time.current,
        stats: {
          "requested_by" => requested_by,
          "employee_id" => employee.id,
          "employee_name" => employee.full_name,
          "remote_employee_id" => employee.vitable_id,
          "bound_entity" => {
            "type" => "employee",
            "id" => employee.vitable_id
          },
          "line" => line
        }
      )
    end

    def mark_token_blocked(sync_run, message)
      sync_run.update!(
        status: "blocked",
        completed_at: Time.current,
        error_message: message,
        stats: sync_run.stats.to_h.merge("blocked_reason" => message)
      )
      sync_run
    end

    def mark_token_needs_credentials(sync_run)
      message = "#{connection.api_key_reference} is not configured"
      sync_run.update!(
        status: "needs_credentials",
        completed_at: Time.current,
        error_message: message,
        stats: sync_run.stats.to_h.merge("blocked_reason" => message)
      )
      sync_run
    end

    def mark_token_succeeded(sync_run, response, employee:)
      issued_at = Time.current
      response_hash = serialize_response(response)
      issuance = EmbeddedSessionIssuanceDto.from_response(response_hash, issued_at:, sync_run_id: sync_run.id)
      persist_issuance(employee, issuance)

      sync_run.update!(
        status: "succeeded",
        completed_at: issued_at,
        error_message: nil,
        stats: sync_run.stats.to_h.merge(
          "token_response" => token_summary(response_hash),
          "issuance" => issuance.to_metadata
        )
      )
      sync_run
    end

    def mark_token_failed(sync_run, error)
      sync_run&.update!(
        status: "failed",
        completed_at: Time.current,
        error_message: error.message,
        stats: sync_run.stats.to_h.merge("error_class" => error.class.name)
      )
      sync_run
    end

    def enrollment_token_block_reason(employee)
      @eligibility_repository.enrollment_token_block_reason(employee)
    end

    private

    def session_candidates
      employees.to_a.select { |employee| enrollment_candidates(employee).any? }
    end

    def enrollment_candidates(employee)
      employee.enrollments.select { |enrollment| enrollment.status.in?(%w[pending accepted]) }
    end

    def line_or_holdback_for(employee)
      active_enrollments = enrollment_candidates(employee)
      eligibility_block = enrollment_token_block_reason(employee)
      return holdback_for(employee, active_enrollments, "eligibility_terminated", eligibility_block) if eligibility_block.present?

      return holdback_for(employee, active_enrollments, "remote_employee_id", "Employee needs a Vitable employee ID before a bound enrollment token can be issued.") if employee.vitable_id.blank?

      line_for(employee, active_enrollments)
    end

    def line_for(employee, active_enrollments)
      pending = active_enrollments.count { |enrollment| enrollment.status == "pending" }
      accepted = active_enrollments.count { |enrollment| enrollment.status == "accepted" }

      {
        "employee_id" => employee.id,
        "employee_name" => employee.full_name,
        "email" => employee.email,
        "department_name" => employee.department&.name || "Unassigned",
        "location_name" => employee.work_location&.name || "No location",
        "remote_employee_id" => employee.vitable_id,
        "enrollment_ids" => active_enrollments.map(&:id),
        "plan_names" => active_enrollments.map { |enrollment| enrollment.benefit_plan.name },
        "pending_enrollment_count" => pending,
        "accepted_enrollment_count" => accepted,
        "next_effective_on" => active_enrollments.map(&:effective_on).compact.min&.iso8601,
        "launch_authorization" => launch_authorization(scope: "employee", employee_id: employee.id),
        "status" => "ready",
        "readiness_reason" => "Ready to issue employee-bound Vitable access token"
      }
    end

    def holdback_for(employee, active_enrollments, reason_code, reason)
      {
        "employee_id" => employee.id,
        "employee_name" => employee.full_name,
        "email" => employee.email,
        "department_name" => employee.department&.name || "Unassigned",
        "location_name" => employee.work_location&.name || "No location",
        "enrollment_ids" => active_enrollments.map(&:id),
        "plan_names" => active_enrollments.map { |enrollment| enrollment.benefit_plan.name },
        "pending_enrollment_count" => active_enrollments.count { |enrollment| enrollment.status == "pending" },
        "status" => "blocked",
        "reason_code" => reason_code,
        "reason" => reason
      }
    end

    def enrollment_widget
      @employer.settings.to_h.fetch("enrollment_widget", "embedded")
    end

    def packet_status(lines, holdbacks)
      return "blocked" if lines.empty?
      return "needs_review" if holdbacks.any?

      "ready"
    end

    def launch_authorization(scope:, employee_id: nil)
      expires_at = WidgetLaunchToken.expires_at

      {
        "type" => "signed_launch_token",
        "header" => WidgetLaunchToken::HEADER,
        "expires_at" => expires_at.iso8601,
        "token" => WidgetLaunchToken.issue(scope:, employer_id: @employer.id, employee_id:, expires_at:)
      }
    end

    def persist_issuance(employee, issuance)
      session_metadata = issuance.to_metadata
      employee.update!(
        metadata: employee.metadata.to_h.stringify_keys.merge(
          "vitable_embedded_session" => session_metadata
        )
      )

      packet = latest_packet.to_h.deep_dup
      return if packet.blank?

      packet["employees"] = packet.fetch("employees", []).map do |line|
        attributes = line.to_h.stringify_keys
        next attributes unless attributes.fetch("employee_id", nil).to_i == employee.id

        attributes.merge(
          "status" => "session_issued",
          "latest_session" => session_metadata,
          "readiness_reason" => "Employee-bound Vitable access token issued; token value was not persisted."
        )
      end

      @employer.update!(settings: @employer.settings.to_h.merge("vitable_embedded_sessions_packet" => packet))
    end

    def token_summary(response)
      PayloadRedactor.redact(response.to_h.deep_stringify_keys)
    end

    def serialize_response(response)
      return {} if response.blank?
      return response.deep_to_h.deep_stringify_keys if response.respond_to?(:deep_to_h)
      return response.to_h.deep_stringify_keys if response.respond_to?(:to_h)

      { "value" => response.to_s }
    end
  end
end
