module Vitable
  class CensusSyncRepository < ApplicationRepository
    MANIFEST_KEY = "vitable_census_sync_batch"
    SUBMISSION_KEY = "vitable_census_sync_last_submission"
    VERIFICATION_KEY = "vitable_census_roster_verification"
    MAX_EMPLOYEES = 5_000
    MIN_EMPLOYEES = 1
    CENSUS_OPERATIONS = %w[census_manifest census_sync remote_roster_refresh].freeze
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

    def latest_manifest
      @employer&.settings.to_h.fetch(MANIFEST_KEY, nil)
    end

    def latest_submission
      @employer&.settings.to_h.fetch(SUBMISSION_KEY, nil)
    end

    def latest_roster_verification
      @employer&.settings.to_h.fetch(VERIFICATION_KEY, nil)
    end

    def sync_runs(limit: 12)
      return SyncRun.none unless connection

      connection.sync_runs.where(operation: CENSUS_OPERATIONS).recent_first.limit(limit)
    end

    def request_logs(limit: 12)
      return ApiRequestLog.none unless connection

      connection.api_request_logs.where(operation: %w[employer.census_sync employer.list_employees]).recent_first.limit(limit)
    end

    def generate_manifest(requested_by:)
      roster = employees.to_a
      offboarding_omissions = offboarding_omissions_for(roster)
      omitted_employee_ids = offboarding_omissions.map { |omission| omission.fetch("employee_id") }
      lines = []
      holdbacks = []

      roster.each do |employee|
        next if omitted_employee_ids.include?(employee.id)

        missing_fields = missing_required_fields(employee)
        if missing_fields.any?
          holdbacks << holdback_for(employee, "missing_required_fields", "Missing #{missing_fields.to_sentence}.")
          next
        end

        line = line_for(employee)
        invalid_fields = invalid_payload_fields(line.fetch("api_payload"))
        if invalid_fields.any?
          holdbacks << holdback_for(employee, "invalid_api_contract_fields", "Invalid #{invalid_fields.to_sentence} for Vitable census sync.")
          next
        end

        if lines.count >= max_employees
          holdbacks << holdback_for(employee, "batch_limit", "Vitable census sync accepts up to #{max_employees} employees per request.")
          next
        end

        lines << line
      end

      manifest = {
        "batch_id" => "vitable_census_#{@employer.id}_#{Time.current.to_i}",
        "generated_at" => Time.current.iso8601,
        "requested_by" => requested_by,
        "employer_id" => @employer.id,
        "remote_employer_id" => @employer.vitable_id,
        "endpoint" => "/v1/employers/:employer_id/census-sync",
        "status" => manifest_status(lines, holdbacks, offboarding_omissions),
        "limits" => {
          "max_employees" => max_employees,
          "requested_employee_count" => roster.count
        },
        "totals" => {
          "employee_count" => roster.count,
          "ready_count" => lines.count,
          "holdback_count" => holdbacks.count,
          "remote_pending_count" => lines.count { |line| line.fetch("remote_employee_id").blank? },
          "offboarding_omission_count" => offboarding_omissions.count
        },
        "employees" => lines,
        "offboarding_omissions" => offboarding_omissions,
        "holdbacks" => holdbacks,
        "api_payload" => {
          "employer_id" => @employer.vitable_id,
          "employees" => lines.map { |line| line.fetch("api_payload") }
        }
      }

      @employer.update!(settings: @employer.settings.to_h.merge(MANIFEST_KEY => manifest))
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
      dto = RemoteCensusSyncResponseDto.from_hash(response_hash).validate!(expected_employer_id: @employer.vitable_id)

      submitted_at = Time.current.iso8601
      submission = census_submission_payload(
        manifest: latest_manifest,
        accepted_at: dto.accepted_at,
        remote_employer_id: dto.remote_employer_id,
        submitted_at:
      )
      mark_manifest_submitted(submission)

      sync_run.update!(
        status: "succeeded",
        completed_at: Time.current,
        error_message: nil,
        stats: sync_run.stats.to_h.merge(
          "remote_response" => response_hash,
          "remote_accepted_at" => dto.accepted_at,
          "remote_employer_id" => dto.remote_employer_id,
          "submitted_employee_count" => submission.fetch("ready_count", 0),
          "offboarding_omission_count" => submission.fetch("offboarding_omission_count", 0)
        )
      )
      sync_run
    end

    def mark_sync_failed(sync_run, error, response: nil)
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

    def create_remote_roster_run(requested_by:)
      connection.sync_runs.create!(
        resource_type: "employer",
        operation: "remote_roster_refresh",
        status: "running",
        started_at: Time.current,
        stats: {
          "requested_by" => requested_by,
          "resource_id" => @employer.vitable_id,
          "endpoint" => "/v1/employers/:employer_id/employees"
        }
      )
    end

    def mark_remote_roster_succeeded(sync_run, response)
      response_hash = serialize_response(response)
      remote_employees = page_data(response_hash, response_label: "Vitable remote roster response")
      mapping = apply_remote_employee_ids(remote_employees)
      manifest = reconcile_manifest_from_remote_roster(remote_employees)
      manifest_lines = manifest.to_h.fetch("employees", [])
      fetched_at = Time.current.iso8601
      verification = roster_verification(manifest:, remote_employees:, mapping:, checked_at: fetched_at)
      settings_update = {
        "vitable_remote_roster" => {
          "fetched_at" => fetched_at,
          "remote_employee_count" => remote_employees.count,
          "matched_employee_count" => mapping.fetch("matched_employee_count"),
          "unmatched_employee_count" => mapping.fetch("unmatched_employee_count"),
          "matched_employee_ids" => mapping.fetch("matched_employee_ids"),
          "matched_remote_ids" => mapping.fetch("matched_remote_ids"),
          "unmatched_remote_ids" => mapping.fetch("unmatched_remote_ids"),
          "verification_status" => verification.fetch("status"),
          "deduction_sync" => mapping.fetch("deduction_sync"),
          "lifecycle_reconciliation" => mapping.fetch("lifecycle_reconciliation")
        }
      }
      settings_update[VERIFICATION_KEY] = verification if latest_submission.present?
      settings_update[MANIFEST_KEY] = manifest if manifest.present?

      @employer.update!(
        settings: @employer.settings.to_h.merge(settings_update)
      )

      sync_run.update!(
        status: "succeeded",
        completed_at: Time.current,
        error_message: nil,
        stats: sync_run.stats.to_h.merge(
          "remote_response" => response_hash,
          "remote_employee_count" => remote_employees.count,
          "matched_employee_count" => mapping.fetch("matched_employee_count"),
          "unmatched_employee_count" => mapping.fetch("unmatched_employee_count"),
          "manifest_synced_count" => manifest_lines.count { |line| line.fetch("status", nil) == "synced" },
          "manifest_remote_pending_count" => manifest.to_h.dig("totals", "remote_pending_count"),
          "verification_status" => verification.fetch("status"),
          "submitted_employee_count" => verification.fetch("submitted_count"),
          "matched_submitted_count" => verification.fetch("matched_submitted_count"),
          "missing_submitted_count" => verification.fetch("missing_submitted_count"),
          "deduction_created_count" => mapping.dig("deduction_sync", "created_count"),
          "deduction_updated_count" => mapping.dig("deduction_sync", "updated_count"),
          "deduction_unchanged_count" => mapping.dig("deduction_sync", "unchanged_count"),
          "inactive_enrollment_count" => mapping.dig("lifecycle_reconciliation", "inactive_enrollment_count"),
          "inactive_payroll_deduction_count" => mapping.dig("lifecycle_reconciliation", "inactive_payroll_deduction_count")
        )
      )
      sync_run
    end

    def mark_remote_roster_failed(sync_run, error, response: nil)
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

    def max_employees
      MAX_EMPLOYEES
    end

    def manifest_status(lines, holdbacks, offboarding_omissions)
      return "blocked" if lines.count < MIN_EMPLOYEES
      return "needs_review" if @employer.vitable_id.blank? || holdbacks.any?

      "ready"
    end

    def missing_required_fields(employee)
      missing = []
      missing << "date of birth" if employee.date_of_birth.blank?
      missing << "phone" if phone_for(employee).blank?
      missing << "email" if email_for(employee).blank?
      missing << "first name" if employee.first_name.to_s.strip.blank?
      missing << "last name" if employee.last_name.to_s.strip.blank?
      missing
    end

    def line_for(employee)
      payload = api_payload_for(employee)

      {
        "employee_id" => employee.id,
        "employee_name" => employee.full_name,
        "email" => payload.fetch("email"),
        "phone" => payload.fetch("phone"),
        "date_of_birth" => payload.fetch("date_of_birth"),
        "start_date" => payload.fetch("start_date", nil),
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
        "first_name" => employee.first_name.to_s.strip,
        "last_name" => employee.last_name.to_s.strip,
        "email" => email_for(employee),
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
        "address_line_1" => location.address_line1.to_s.strip,
        "city" => location.city.to_s.strip,
        "state" => location.state.to_s.strip.upcase,
        "zipcode" => location.postal_code.to_s.strip
      }
    end

    def invalid_payload_fields(payload)
      fields = []
      fields << "email" unless valid_email?(payload.fetch("email", nil))
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

    def sync_stats(manifest:, requested_by:)
      totals = manifest.fetch("totals", {})

      {
        "batch_id" => manifest.fetch("batch_id"),
        "requested_by" => requested_by,
        "resource_id" => @employer.vitable_id.presence || "local_employer_#{@employer.id}",
        "ready_count" => totals.fetch("ready_count", 0),
        "holdback_count" => totals.fetch("holdback_count", 0),
        "remote_pending_count" => totals.fetch("remote_pending_count", 0),
        "offboarding_omission_count" => totals.fetch("offboarding_omission_count", 0),
        "offboarding_omissions" => manifest.fetch("offboarding_omissions", []),
        "endpoint" => manifest.fetch("endpoint"),
        "payload" => manifest.fetch("api_payload", {})
      }
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

    def page_data(response_hash, response_label:)
      RemoteCollectionResponseDto
        .from_response(response_hash, response_label:)
        .records
    end

    def apply_remote_employee_ids(remote_employees)
      matched = []
      unmatched = []
      matched_employee_ids = []
      deduction_sync = PayrollDeductionSyncResultDto.empty
      lifecycle_reconciliation = EmployeeLifecycleReconciliationDto.empty

      remote_employees.each do |remote_employee|
        validate_remote_employee_identity!(remote_employee)
        employee = employee_for_remote(remote_employee)
        if employee
          remote_employee_id = remote_employee.fetch("id")
          refreshed_at = Time.current.iso8601
          remote_hire_date = remote_employee_hire_date(remote_employee)
          update_attributes = {
            vitable_id: remote_employee_id,
            metadata: employee.metadata.to_h.stringify_keys.merge(remote_employee_metadata(remote_employee, refreshed_at)).compact
          }
          local_employment_status = employee_employment_status_for(remote_employee)
          update_attributes[:employment_status] = local_employment_status if local_employment_status.present? && employee.employment_status != local_employment_status
          update_attributes[:start_on] = remote_hire_date if remote_hire_date.present? && employee.start_on != remote_hire_date
          employee.update!(update_attributes)
          deduction_sync = deduction_sync.merge(
            PayrollDeductionRepository.new.sync_employee_deductions(
              employee:,
              remote_deductions: remote_employee.fetch("deductions", []),
              source: "vitable_remote_roster",
              reconciled_at: refreshed_at
            )
          )
          lifecycle_reconciliation = lifecycle_reconciliation.merge(
            deactivate_employee_benefits(employee, remote_employee, refreshed_at:)
          )
          matched << remote_employee_id
          matched_employee_ids << employee.id
        else
          unmatched << remote_employee.fetch("id", nil)
        end
      end

      {
        "matched_employee_count" => matched.compact.count,
        "unmatched_employee_count" => unmatched.compact.count,
        "matched_employee_ids" => matched_employee_ids.compact,
        "matched_remote_ids" => matched.compact,
        "unmatched_remote_ids" => unmatched.compact,
        "deduction_sync" => deduction_sync.to_metadata,
        "lifecycle_reconciliation" => lifecycle_reconciliation.to_metadata
      }
    end

    def deactivate_employee_benefits(employee, remote_employee, refreshed_at:)
      return EmployeeLifecycleReconciliationDto.empty unless employee_employment_status_for(remote_employee) == "terminated"

      EmployeeEligibilityRepository.new.deactivate_benefits!(
        employee:,
        source: "vitable_remote_roster",
        reconciled_at: refreshed_at
      )
    end

    def employee_for_remote(remote_employee)
      reference_id = remote_employee.fetch("reference_id", nil).to_s
      if reference_id.match?(/\Amusto_employee_\d+\z/)
        employee_id = reference_id.delete_prefix("musto_employee_").to_i
        employee = @employer.employees.find_by(id: employee_id)
        return employee if employee
      end

      @employer.employees.find_by(email: remote_employee.fetch("email", nil))
    end

    def employee_employment_status_for(remote_employee)
      normalized = remote_employee.fetch("status", nil).to_s.downcase
      return "terminated" if normalized.in?(%w[inactive deactivated terminated])
      return "active" if normalized.in?(%w[active reactivated])

      nil
    end

    def census_submission_payload(manifest:, accepted_at:, remote_employer_id:, submitted_at:)
      manifest = manifest.to_h.stringify_keys
      employees = manifest.fetch("employees", [])
      offboarding_omissions = manifest.fetch("offboarding_omissions", [])

      {
        "batch_id" => manifest.fetch("batch_id", nil),
        "status" => "accepted",
        "accepted_at" => accepted_at,
        "submitted_at" => submitted_at,
        "remote_employer_id" => remote_employer_id,
        "ready_count" => employees.count,
        "offboarding_omission_count" => offboarding_omissions.count,
        "employee_reference_ids" => employees.filter_map { |employee| employee.to_h.stringify_keys.fetch("reference_id", nil) },
        "offboarding_omissions" => offboarding_omissions
      }.compact
    end

    def mark_manifest_submitted(submission)
      manifest = latest_manifest.to_h.deep_dup
      submitted_at = submission.fetch("submitted_at")
      accepted_at = submission.fetch("accepted_at", nil)

      manifest["employees"] = manifest.fetch("employees", []).map do |line|
        employee = employee_for_manifest_line(line)
        mark_employee_census_submitted(employee, submission) if employee

        line.to_h.stringify_keys.merge(
          "status" => "submitted",
          "readiness_status" => "submitted",
          "readiness_reason" => "Accepted by Vitable census sync; refresh the remote roster for employee IDs.",
          "submitted_at" => submitted_at,
          "accepted_at" => accepted_at
        ).compact
      end
      manifest["offboarding_omissions"] = manifest.fetch("offboarding_omissions", []).map do |omission|
        attributes = omission.to_h.stringify_keys
        employee = employee_for_manifest_line(attributes)
        mark_employee_census_deactivation_submitted(employee, submission) if employee

        attributes.merge(
          "status" => "submitted",
          "readiness_status" => "submitted",
          "readiness_reason" => "Omitted from the accepted census sync for Vitable deactivation.",
          "submitted_at" => submitted_at,
          "accepted_at" => accepted_at
        ).compact
      end

      @employer.update!(
        settings: @employer.settings.to_h.merge(
          MANIFEST_KEY => manifest,
          SUBMISSION_KEY => submission
        )
      )
    end

    def mark_employee_census_deactivation_submitted(employee, submission)
      employee.update!(
        metadata: employee.metadata.to_h.stringify_keys.merge(
          "vitable_census_sync_status" => "deactivation_submitted",
          "vitable_census_sync_batch_id" => submission.fetch("batch_id", nil),
          "vitable_census_sync_accepted_at" => submission.fetch("accepted_at", nil),
          "vitable_census_sync_submitted_at" => submission.fetch("submitted_at", nil)
        ).compact
      )
    end

    def mark_employee_census_submitted(employee, submission)
      employee.update!(
        metadata: employee.metadata.to_h.stringify_keys.merge(
          "vitable_census_sync_status" => "submitted",
          "vitable_census_sync_batch_id" => submission.fetch("batch_id", nil),
          "vitable_census_sync_accepted_at" => submission.fetch("accepted_at", nil),
          "vitable_census_sync_submitted_at" => submission.fetch("submitted_at", nil)
        ).compact
      )
    end

    def reconcile_manifest_from_remote_roster(remote_employees)
      manifest_payload = latest_manifest
      return unless manifest_payload.present?

      manifest = manifest_payload.to_h.deep_dup
      employees = manifest.fetch("employees", [])
      remote_by_reference = remote_employees.index_by { |remote_employee| remote_employee.fetch("reference_id", nil) }
      remote_by_email = remote_employees.index_by { |remote_employee| remote_employee.fetch("email", nil).to_s.downcase }

      manifest["employees"] = employees.map do |line|
        attributes = line.to_h.stringify_keys
        remote_employee = remote_by_reference[attributes.fetch("reference_id", nil)] ||
          remote_by_email[attributes.fetch("email", nil).to_s.downcase]
        next remote_pending_line(attributes) unless remote_employee

        attributes.merge(
          "remote_employee_id" => remote_employee.fetch("id", nil),
          "remote_member_id" => remote_employee.fetch("member_id", nil),
          "remote_status" => remote_employee.fetch("status", nil),
          "remote_employee_class" => remote_employee.fetch("employee_class", nil),
          "remote_hire_date" => remote_employee_hire_date(remote_employee)&.iso8601,
          "remote_termination_date" => remote_employee_termination_date(remote_employee)&.iso8601,
          "remote_deduction_count" => Array(remote_employee.fetch("deductions", [])).count,
          "status" => "synced",
          "readiness_status" => "synced",
          "readiness_reason" => "Matched Vitable employee from remote roster."
        ).compact
      end

      totals = manifest.fetch("totals", {}).to_h.stringify_keys
      manifest["totals"] = totals.merge(
        "remote_pending_count" => manifest.fetch("employees", []).count { |line| line.fetch("remote_employee_id", nil).blank? },
        "remote_synced_count" => manifest.fetch("employees", []).count { |line| line.fetch("remote_employee_id", nil).present? }
      )
      manifest
    end

    def remote_pending_line(attributes)
      employee = employee_for_manifest_line(attributes)
      mark_employee_census_remote_pending(employee) if employee

      attributes.merge(
        "status" => "remote_pending",
        "readiness_status" => "pending",
        "readiness_reason" => "Not present in the latest Vitable remote roster."
      )
    end

    def mark_employee_census_remote_pending(employee)
      employee.update!(
        metadata: employee.metadata.to_h.stringify_keys.merge(
          "vitable_census_sync_status" => "remote_pending",
          "vitable_last_refreshed_at" => Time.current.iso8601
        )
      )
    end

    def validate_remote_employee_identity!(remote_employee)
      reference = remote_employee.fetch("reference_id", nil).presence || remote_employee.fetch("email", nil).presence || "unknown remote employee"
      raise ArgumentError, "Vitable remote roster employee #{reference} did not include a remote employee ID" if remote_employee.fetch("id", nil).blank?
      raise ArgumentError, "Vitable remote roster employee #{reference} did not include a remote member ID" if remote_employee.fetch("member_id", nil).blank?
    end

    def remote_employee_metadata(remote_employee, refreshed_at)
      {
        "vitable_census_sync_status" => "synced",
        "vitable_remote_status" => remote_employee.fetch("status", nil),
        "vitable_member_id" => remote_employee.fetch("member_id", nil),
        "vitable_remote_reference_id" => remote_employee.fetch("reference_id", nil),
        "vitable_remote_employee_class" => remote_employee.fetch("employee_class", nil),
        "vitable_remote_hire_date" => remote_employee_hire_date(remote_employee)&.iso8601,
        "vitable_remote_termination_date" => remote_employee_termination_date(remote_employee)&.iso8601,
        "vitable_remote_date_of_birth" => remote_date(remote_employee, "date_of_birth")&.iso8601,
        "vitable_remote_phone" => remote_employee.fetch("phone", nil),
        "vitable_remote_address" => remote_employee_address(remote_employee),
        "vitable_remote_deductions" => remote_employee.fetch("deductions", []),
        "vitable_last_refreshed_at" => refreshed_at,
        "vitable_last_resource_snapshot" => remote_employee_summary(remote_employee)
      }
    end

    def remote_employee_summary(remote_employee)
      remote_employee.slice(
        "id",
        "reference_id",
        "email",
        "first_name",
        "last_name",
        "status",
        "member_id",
        "employee_class",
        "hire_date",
        "termination_date",
        "date_of_birth",
        "phone"
      ).compact
    end

    def remote_employee_hire_date(remote_employee)
      remote_date(remote_employee, "hire_date") || remote_date(remote_employee, "start_date")
    end

    def remote_employee_termination_date(remote_employee)
      remote_date(remote_employee, "termination_date") || remote_date(remote_employee, "terminated_on")
    end

    def remote_date(remote_employee, key)
      value = remote_employee.fetch(key, nil)
      return value if value.is_a?(Date)
      return value.to_date if value.respond_to?(:to_date)
      return if value.blank?

      Date.iso8601(value.to_s)
    rescue ArgumentError
      nil
    end

    def remote_employee_address(remote_employee)
      address = remote_employee.fetch("address", nil)
      return unless address.respond_to?(:to_h)

      address.to_h.stringify_keys.slice("address_line_1", "address_line_2", "city", "state", "zipcode").compact
    end

    def roster_verification(manifest:, remote_employees:, mapping:, checked_at:)
      manifest_lines = manifest.to_h.fetch("employees", []).map { |line| line.to_h.stringify_keys }
      submitted_references = submitted_reference_ids
      matched_references = manifest_lines
        .select { |line| submitted_references.include?(line.fetch("reference_id", nil)) && line.fetch("remote_employee_id", nil).present? }
        .filter_map { |line| line.fetch("reference_id", nil) }
      missing_references = submitted_references - matched_references

      {
        "status" => roster_verification_status(submitted_references, missing_references),
        "checked_at" => checked_at,
        "submitted_count" => submitted_references.count,
        "remote_employee_count" => remote_employees.count,
        "matched_submitted_count" => matched_references.count,
        "missing_submitted_count" => missing_references.count,
        "unmatched_remote_count" => mapping.fetch("unmatched_employee_count"),
        "missing_reference_ids" => missing_references,
        "reason" => roster_verification_reason(submitted_references, matched_references, missing_references)
      }
    end

    def submitted_reference_ids
      submission = latest_submission.to_h.stringify_keys
      references = submission.fetch("employee_reference_ids", [])
      return references if latest_submission.present?

      []
    end

    def roster_verification_status(submitted_references, missing_references)
      return "pending" if submitted_references.empty?
      return "verified" if missing_references.empty?

      "needs_review"
    end

    def roster_verification_reason(submitted_references, matched_references, missing_references)
      return "No submitted census rows are available for verification." if submitted_references.empty?
      return "All submitted census rows were found in the latest Vitable remote roster." if missing_references.empty?

      "#{missing_references.count} of #{submitted_references.count} submitted census rows were not found in the latest Vitable remote roster."
    end

    def employee_for_manifest_line(line)
      attributes = line.to_h.stringify_keys
      employee_id = attributes.fetch("employee_id", nil)
      employee = @employer.employees.find_by(id: employee_id) if employee_id.present?
      employee || employee_for_remote(attributes)
    end

    def offboarding_omissions_for(roster)
      packet = @employer.settings.to_h.fetch(Benefits::OffboardingRepository::PACKET_KEY, {}).to_h.stringify_keys
      return [] unless packet.fetch("status", nil) == "ready"

      roster_by_id = roster.index_by(&:id)
      packet.fetch("terminations", [])
        .map { |line| line.to_h.stringify_keys }
        .select { |line| line.fetch("member_type", nil) == "employee" && line.fetch("status", nil) == "ready" }
        .filter_map do |line|
          employee_id = line.fetch("employee_id", nil).to_i
          employee = roster_by_id[employee_id]
          next unless employee

          {
            "employee_id" => employee.id,
            "employee_name" => employee.full_name,
            "event_id" => line.fetch("event_id", nil),
            "reference_id" => "musto_employee_#{employee.id}",
            "remote_employee_id" => employee.vitable_id,
            "coverage_end_on" => line.fetch("coverage_end_on", nil),
            "reason_code" => "benefits_offboarding",
            "reason" => "Omitted from census sync so Vitable deactivates the employee and terminates active enrollments."
          }.compact
        end
        .uniq { |line| line.fetch("employee_id") }
    end
  end
end
