module Vitable
  class CensusSyncQuery
    def initialize(employer_repository: Employers::EmployerRepository.new)
      @employer = employer_repository.first_for_operations
      @repository = CensusSyncRepository.new(employer: @employer)
    end

    def call
      manifest_payload = @repository.latest_manifest
      submission_payload = @repository.latest_submission
      verification_payload = @repository.latest_roster_verification
      latest_manifest = manifest_payload.present? ? CensusSyncManifestDto.from_hash(manifest_payload) : nil
      latest_submission = submission_payload.present? ? CensusSyncSubmissionDto.from_hash(submission_payload) : nil
      latest_verification = verification_payload.present? ? CensusRosterVerificationDto.from_hash(verification_payload) : nil
      employees = manifest_payload.to_h.fetch("employees", []).map { |payload| CensusSyncEmployeeDto.from_hash(payload) }
      offboarding_omissions = manifest_payload.to_h.fetch("offboarding_omissions", []).map { |payload| CensusSyncOffboardingOmissionDto.from_hash(payload) }
      holdbacks = manifest_payload.to_h.fetch("holdbacks", []).map { |payload| CensusSyncHoldbackDto.from_hash(payload) }
      connection = @repository.connection
      roster = @repository.employees.to_a

      CensusSyncCenterDto.new(
        employer: Operations::EmployerContextDto.from_record(@employer),
        connection_id: connection&.id,
        connection_status: connection&.status || "missing",
        credentials_present: connection&.credentials_present? || false,
        api_key_reference: connection&.api_key_reference || "VITABLE_CONNECT_API_KEY",
        remote_employer_id: @employer&.vitable_id,
        metrics: metrics(roster, latest_manifest, holdbacks, connection),
        preflight_checks: preflight_checks(roster, latest_manifest, holdbacks, connection),
        employees:,
        offboarding_omissions:,
        holdbacks:,
        latest_manifest:,
        latest_submission:,
        latest_verification:,
        sync_runs: @repository.sync_runs.map { |sync| Operations::SyncRunDto.from_record(sync) },
        request_logs: @repository.request_logs.map { |log| Operations::ApiRequestLogDto.from_record(log) },
        endpoint_path: "/v1/employers/:employer_id/census-sync",
        docs_url: "https://developer.vitablehealth.com/",
        ruby_docs_url: "https://developer.vitablehealth.com/api/ruby"
      )
    end

    private

    def metrics(roster, latest_manifest, holdbacks, connection)
      ready_count = latest_manifest&.ready_count || 0
      last_sync = @repository.sync_runs.first
      remote_id_count = roster.count { |employee| employee.vitable_id.present? }
      omission_count = latest_manifest&.offboarding_omission_count || 0

      [
        CensusSyncMetricDto.new(label: "Active employees", value: roster.count, hint: "eligible for census review", status: roster.any? ? "ready" : "empty", accent: "bg-cyan-500", format: "number"),
        CensusSyncMetricDto.new(label: "Ready rows", value: ready_count, hint: "complete required Vitable fields", status: ready_count.positive? ? "ready" : "needs_review", accent: "bg-emerald-500", format: "number"),
        CensusSyncMetricDto.new(label: "Remote IDs", value: remote_id_count, hint: "mapped from Vitable roster", status: remote_id_count == roster.count && roster.any? ? "ready" : "pending", accent: "bg-violet-500", format: "number"),
        CensusSyncMetricDto.new(label: "Offboarding omissions", value: omission_count, hint: "employees omitted for deactivation", status: omission_count.positive? ? "ready" : "pending", accent: "bg-rose-500", format: "number"),
        CensusSyncMetricDto.new(label: "Holdbacks", value: holdbacks.count, hint: "missing DOB, phone, or batch capacity", status: holdbacks.any? ? "blocked" : "ready", accent: "bg-rose-500", format: "number"),
        CensusSyncMetricDto.new(label: "Roster verification", value: verification_label, hint: verification_hint, status: verification_status, accent: "bg-sky-500", format: "text"),
        CensusSyncMetricDto.new(label: "Last submit", value: last_sync&.status&.humanize || "Not sent", hint: connection ? "credential-aware sync run" : "no Vitable connection", status: last_sync&.status || "pending", accent: "bg-indigo-500", format: "text")
      ]
    end

    def preflight_checks(roster, latest_manifest, holdbacks, connection)
      [
        CensusSyncPreflightCheckDto.new(
          label: "Vitable connection",
          status: connection ? connection.status : "missing",
          detail: connection ? "Connection ##{connection.id} is mapped to #{@employer.organization.name}." : "Create a Vitable integration connection before submitting census sync."
        ),
        CensusSyncPreflightCheckDto.new(
          label: "API credentials",
          status: connection&.credentials_present? ? "ready" : "needs_credentials",
          detail: connection&.credentials_present? ? "#{connection.api_key_reference} is available to Rails." : "Set #{connection&.api_key_reference || "VITABLE_CONNECT_API_KEY"} before live census submission."
        ),
        CensusSyncPreflightCheckDto.new(
          label: "Remote employer ID",
          status: @employer&.vitable_id.present? ? "ready" : "blocked",
          detail: @employer&.vitable_id.presence || "A remote Vitable employer ID is required for /v1/employers/:id/census-sync."
        ),
        CensusSyncPreflightCheckDto.new(
          label: "Required employee fields",
          status: holdbacks.any? ? "needs_review" : "ready",
          detail: holdbacks.any? ? "#{holdbacks.count} employees are missing required census fields." : "#{latest_manifest&.ready_count || 0} employees have DOB, phone, email, and name data."
        ),
        CensusSyncPreflightCheckDto.new(
          label: "Batch size",
          status: batch_size_status(latest_manifest, roster),
          detail: batch_size_detail(latest_manifest, roster)
        ),
        CensusSyncPreflightCheckDto.new(
          label: "Remote roster mapping",
          status: roster.any? && roster.all? { |employee| employee.vitable_id.present? } ? "ready" : "pending",
          detail: "#{roster.count { |employee| employee.vitable_id.present? }} of #{roster.count} active employees have Vitable employee IDs."
        ),
        CensusSyncPreflightCheckDto.new(
          label: "Async roster verification",
          status: verification_status,
          detail: verification_hint
        ),
        CensusSyncPreflightCheckDto.new(
          label: "Manifest",
          status: latest_manifest ? latest_manifest.status : "pending",
          detail: latest_manifest ? "Generated #{latest_manifest.batch_id} by #{latest_manifest.requested_by}." : "Generate a census manifest before submit."
        )
      ]
    end

    def verification
      @verification ||= @repository.latest_roster_verification.present? ? CensusRosterVerificationDto.from_hash(@repository.latest_roster_verification) : nil
    end

    def batch_size_status(latest_manifest, roster)
      return "blocked" if latest_manifest&.ready_count.to_i < CensusSyncRepository::MIN_EMPLOYEES
      return "blocked" if roster.count > CensusSyncRepository::MAX_EMPLOYEES

      "ready"
    end

    def batch_size_detail(latest_manifest, roster)
      ready_count = latest_manifest&.ready_count.to_i
      return "Generate at least #{CensusSyncRepository::MIN_EMPLOYEES} ready employee row before submitting census sync." if ready_count < CensusSyncRepository::MIN_EMPLOYEES

      "#{roster.count} of #{CensusSyncRepository::MAX_EMPLOYEES} maximum employees selected."
    end

    def verification_status
      verification&.status || "pending"
    end

    def verification_label
      return "Not checked" unless verification

      "#{verification.matched_submitted_count}/#{verification.submitted_count}"
    end

    def verification_hint
      verification&.reason || "Refresh the remote roster after Vitable accepts a census sync."
    end
  end
end
