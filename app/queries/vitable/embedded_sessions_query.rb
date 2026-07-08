module Vitable
  class EmbeddedSessionsQuery
    def initialize(employer_repository: Employers::EmployerRepository.new)
      @employer = employer_repository.first_for_operations
      @repository = EmbeddedSessionsRepository.new(employer: @employer)
    end

    def call
      packet_payload = @repository.latest_packet
      latest_packet = packet_payload.present? ? EmbeddedSessionPacketDto.from_hash(packet_payload) : nil
      employees = packet_payload.to_h.fetch("employees", []).map { |payload| EmbeddedSessionEmployeeDto.from_hash(payload) }
      holdbacks = packet_payload.to_h.fetch("holdbacks", []).map { |payload| EmbeddedSessionHoldbackDto.from_hash(payload) }
      connection = @repository.connection

      EmbeddedSessionsCenterDto.new(
        employer: Operations::EmployerContextDto.from_record(@employer),
        connection_id: connection&.id,
        connection_status: connection&.status || "missing",
        credentials_present: connection&.credentials_present? || false,
        api_key_reference: connection&.api_key_reference || "VITABLE_CONNECT_API_KEY",
        metrics: metrics(employees, holdbacks, latest_packet, connection),
        preflight_checks: preflight_checks(employees, holdbacks, latest_packet, connection),
        employees:,
        holdbacks:,
        latest_packet:,
        token_runs: @repository.token_runs.map { |sync| Operations::SyncRunDto.from_record(sync) },
        request_logs: @repository.request_logs.map { |log| Operations::ApiRequestLogDto.from_record(log) },
        docs_url: "https://developer.vitablehealth.com/",
        ruby_docs_url: "https://developer.vitablehealth.com/api/ruby",
        widget_base_url: ENV.fetch("VITABLE_WIDGET_BASE_URL", "https://app.vitablehealth.com")
      )
    end

    private

    def metrics(employees, holdbacks, latest_packet, connection)
      last_token_run = @repository.token_runs.first

      [
        EmbeddedSessionMetricDto.new(label: "Session-ready", value: employees.count, hint: "employees with remote Vitable IDs", status: employees.any? ? "ready" : "needs_review", accent: "bg-cyan-500", format: "number"),
        EmbeddedSessionMetricDto.new(label: "Active sessions", value: employees.count(&:session_active?), hint: "employee-bound tokens still inside expiry", status: employees.any?(&:session_active?) ? "ready" : "pending", accent: "bg-emerald-500", format: "number"),
        EmbeddedSessionMetricDto.new(label: "Pending elections", value: latest_packet&.pending_election_count || 0, hint: "can open embedded enrollment", status: latest_packet&.pending_election_count.to_i.positive? ? "ready" : "pending", accent: "bg-indigo-500", format: "number"),
        EmbeddedSessionMetricDto.new(label: "Holdbacks", value: holdbacks.count, hint: "remote IDs or election data missing", status: holdbacks.any? ? "blocked" : "ready", accent: "bg-rose-500", format: "number"),
        EmbeddedSessionMetricDto.new(label: "Last token", value: last_token_run&.status&.humanize || "Not issued", hint: connection ? "employee-bound access token audit" : "no Vitable connection", status: last_token_run&.status || "pending", accent: "bg-emerald-500", format: "text")
      ]
    end

    def preflight_checks(employees, holdbacks, latest_packet, connection)
      [
        EmbeddedSessionPreflightCheckDto.new(
          label: "Vitable connection",
          status: connection ? connection.status : "missing",
          detail: connection ? "Connection ##{connection.id} can issue scoped tokens." : "Create a Vitable integration connection before issuing embedded sessions."
        ),
        EmbeddedSessionPreflightCheckDto.new(
          label: "API credentials",
          status: connection&.credentials_present? ? "ready" : "needs_credentials",
          detail: connection&.credentials_present? ? "#{connection.api_key_reference} is available to Rails." : "Set #{connection&.api_key_reference || "VITABLE_CONNECT_API_KEY"} before live token issuance."
        ),
        EmbeddedSessionPreflightCheckDto.new(
          label: "Enrollment widget",
          status: @employer&.settings.to_h.fetch("enrollment_widget", nil).present? ? "ready" : "needs_review",
          detail: @employer&.settings.to_h.fetch("enrollment_widget", "No embedded enrollment widget setting is configured.").to_s
        ),
        EmbeddedSessionPreflightCheckDto.new(
          label: "Launch authorization",
          status: employees.any?(&:launch_token_active?) ? "ready" : "pending",
          detail: employees.any?(&:launch_token_active?) ? "#{employees.count(&:launch_token_active?)} employee launch tokens are ready for the widget broker." : "Generate a session packet to prepare signed widget launch tokens."
        ),
        EmbeddedSessionPreflightCheckDto.new(
          label: "Remote employee IDs",
          status: holdbacks.any? ? "needs_review" : "ready",
          detail: holdbacks.any? ? "#{holdbacks.count} employees need Vitable employee IDs before tokens can be bound." : "#{employees.count} employees can receive employee-bound tokens."
        ),
        EmbeddedSessionPreflightCheckDto.new(
          label: "Session packet",
          status: latest_packet ? latest_packet.status : "pending",
          detail: latest_packet ? "Generated #{latest_packet.packet_id} by #{latest_packet.requested_by}." : "Generate an embedded session packet before issuing employee sessions."
        )
      ]
    end
  end
end
