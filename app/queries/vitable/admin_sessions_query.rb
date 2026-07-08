module Vitable
  class AdminSessionsQuery
    def initialize(employer_repository: Employers::EmployerRepository.new)
      @employer = employer_repository.first_for_operations
      @repository = AdminSessionsRepository.new(employer: @employer)
    end

    def call
      packet_payload = @repository.latest_packet
      latest_packet = packet_payload.present? ? AdminSessionPacketDto.from_hash(packet_payload) : nil
      widgets = packet_payload.to_h.fetch("widgets", AdminSessionsRepository::WIDGETS).map do |payload|
        AdminSessionWidgetDto.new(**payload.to_h.stringify_keys.reverse_merge("status" => "pending").symbolize_keys)
      end
      holdbacks = packet_payload.to_h.fetch("holdbacks", [])
      connection = @repository.connection
      latest_issuance = @repository.latest_issuance

      AdminSessionsCenterDto.new(
        employer: Operations::EmployerContextDto.from_record(@employer),
        connection_id: connection&.id,
        connection_status: connection&.status || "missing",
        credentials_present: connection&.credentials_present? || false,
        api_key_reference: connection&.api_key_reference || "VITABLE_CONNECT_API_KEY",
        remote_employer_id: @employer&.vitable_id,
        metrics: metrics(widgets, holdbacks, latest_packet, latest_issuance, connection),
        preflight_checks: preflight_checks(widgets, holdbacks, latest_packet, latest_issuance, connection),
        widgets:,
        holdbacks:,
        latest_packet:,
        latest_issuance:,
        token_runs: @repository.token_runs.map { |sync| Operations::SyncRunDto.from_record(sync) },
        request_logs: @repository.request_logs.map { |log| Operations::ApiRequestLogDto.from_record(log) },
        docs_url: "https://developer.vitablehealth.com/",
        ruby_docs_url: "https://developer.vitablehealth.com/api/ruby",
        administration_docs_url: "https://developer.vitablehealth.com/embedded_benefits/guides/benefits-administration/"
      )
    end

    private

    def metrics(widgets, holdbacks, latest_packet, latest_issuance, connection)
      last_token_run = @repository.token_runs.first

      [
        AdminSessionMetricDto.new(label: "Admin widgets", value: widgets.count, hint: "benefits and billing experiences", status: widgets.any? ? "ready" : "pending", accent: "bg-indigo-500", format: "number"),
        AdminSessionMetricDto.new(label: "Remote employer", value: @employer&.vitable_id.presence || "Missing", hint: "required for employer-bound token", status: @employer&.vitable_id.present? ? "ready" : "blocked", accent: "bg-cyan-500", format: "text"),
        AdminSessionMetricDto.new(label: "Active session", value: latest_issuance.active? ? "Issued" : "Not issued", hint: "token metadata only; secret not stored", status: latest_issuance.active? ? "ready" : "pending", accent: "bg-emerald-500", format: "text"),
        AdminSessionMetricDto.new(label: "Holdbacks", value: holdbacks.count, hint: "items blocking admin launch", status: holdbacks.any? ? "blocked" : "ready", accent: "bg-rose-500", format: "number"),
        AdminSessionMetricDto.new(label: "Last token", value: last_token_run&.status&.humanize || "Not issued", hint: connection ? "employer-bound access token audit" : "no Vitable connection", status: last_token_run&.status || "pending", accent: "bg-amber-500", format: "text")
      ]
    end

    def preflight_checks(widgets, holdbacks, latest_packet, latest_issuance, connection)
      [
        AdminSessionPreflightCheckDto.new(
          label: "Vitable connection",
          status: connection ? connection.status : "missing",
          detail: connection ? "Connection ##{connection.id} can issue scoped admin tokens." : "Create a Vitable integration connection before issuing employer admin sessions."
        ),
        AdminSessionPreflightCheckDto.new(
          label: "API credentials",
          status: connection&.credentials_present? ? "ready" : "needs_credentials",
          detail: connection&.credentials_present? ? "#{connection.api_key_reference} is available to Rails." : "Set #{connection&.api_key_reference || "VITABLE_CONNECT_API_KEY"} before live admin token issuance."
        ),
        AdminSessionPreflightCheckDto.new(
          label: "Remote employer",
          status: @employer&.vitable_id.present? ? "ready" : "blocked",
          detail: @employer&.vitable_id.present? ? @employer.vitable_id : "Provision or reconcile the Vitable employer before admin launch."
        ),
        AdminSessionPreflightCheckDto.new(
          label: "Admin widgets",
          status: widgets.any? ? "ready" : "pending",
          detail: widgets.map(&:name).to_sentence.presence || "No employer widgets are configured."
        ),
        AdminSessionPreflightCheckDto.new(
          label: "Session packet",
          status: latest_packet ? latest_packet.status : "pending",
          detail: latest_packet ? "Generated #{latest_packet.packet_id} by #{latest_packet.requested_by}." : "Generate an admin session packet before issuing employer sessions."
        ),
        AdminSessionPreflightCheckDto.new(
          label: "Latest issued session",
          status: latest_issuance.active? ? "ready" : "pending",
          detail: latest_issuance.expires_at.present? ? "Expires at #{latest_issuance.expires_at.iso8601}." : "No employer-bound admin session has been issued."
        ),
        AdminSessionPreflightCheckDto.new(
          label: "Launch readiness",
          status: holdbacks.any? ? "blocked" : "ready",
          detail: holdbacks.any? ? "#{holdbacks.count} items need attention before launch." : "Employer admin widgets can request a short-lived employer-bound token."
        )
      ]
    end
  end
end
