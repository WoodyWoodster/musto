module Vitable
  class EmployerProvisioningQuery
    def initialize(employer_repository: Employers::EmployerRepository.new)
      @employer = employer_repository.first_for_operations
      @repository = EmployerProvisioningRepository.new(employer: @employer)
    end

    def call
      packet_payload = @repository.latest_packet
      display_packet = packet_payload.presence || @repository.preview_packet(requested_by: "preview")
      latest_packet = packet_payload.present? ? EmployerProvisioningPacketDto.from_hash(packet_payload) : nil
      payload = EmployerProvisioningPayloadDto.from_hash(display_packet)
      holdbacks = display_packet.to_h.fetch("holdbacks", []).map { |entry| EmployerProvisioningHoldbackDto.from_hash(entry) }
      connection = @repository.connection

      EmployerProvisioningCenterDto.new(
        employer: Operations::EmployerContextDto.from_record(@employer),
        connection_id: connection&.id,
        connection_status: connection&.status || "missing",
        credentials_present: connection&.credentials_present? || false,
        api_key_reference: connection&.api_key_reference || "VITABLE_CONNECT_API_KEY",
        remote_employer_id: @employer&.vitable_id,
        metrics: metrics(latest_packet, holdbacks, connection),
        preflight_checks: preflight_checks(latest_packet, payload, holdbacks, connection),
        payload:,
        holdbacks:,
        latest_packet:,
        sync_runs: @repository.sync_runs.map { |sync| Operations::SyncRunDto.from_record(sync) },
        request_logs: @repository.request_logs.map { |log| Operations::ApiRequestLogDto.from_record(log) },
        docs_url: "https://developer.vitablehealth.com/",
        ruby_docs_url: "https://developer.vitablehealth.com/api/ruby",
        onboarding_docs_url: "https://developer.vitablehealth.com/embedded_benefits/guides/employer-onboarding/"
      )
    end

    private

    def metrics(latest_packet, holdbacks, connection)
      last_run = @repository.sync_runs.first

      [
        EmployerProvisioningMetricDto.new(label: "Remote employer", value: @employer&.vitable_id.presence || "Create pending", hint: "Vitable employer identifier", status: @employer&.vitable_id.present? ? "ready" : "pending", accent: "bg-indigo-500", format: "text"),
        EmployerProvisioningMetricDto.new(label: "Required fields", value: holdbacks.count.zero? ? "Complete" : "#{holdbacks.count} missing", hint: "legal entity, billing email, address, payroll cadence", status: holdbacks.any? ? "blocked" : "ready", accent: "bg-emerald-500", format: "text"),
        EmployerProvisioningMetricDto.new(label: "Pay frequency", value: @employer&.settings.to_h.fetch("pay_frequency", "missing").to_s.humanize, hint: "mapped to Vitable settings enum", status: @employer&.settings.to_h.fetch("pay_frequency", nil).present? ? "ready" : "blocked", accent: "bg-cyan-500", format: "text"),
        EmployerProvisioningMetricDto.new(label: "Eligibility policy", value: eligibility_policy_value, hint: "classification and waiting period", status: eligibility_policy_status, accent: "bg-violet-500", format: "text"),
        EmployerProvisioningMetricDto.new(label: "Last provision", value: last_run&.status&.humanize || "Not sent", hint: connection ? "credential-aware provisioning attempt" : "no Vitable connection", status: last_run&.status || "pending", accent: "bg-amber-500", format: "text")
      ]
    end

    def preflight_checks(latest_packet, payload, holdbacks, connection)
      [
        EmployerProvisioningPreflightCheckDto.new(
          label: "Vitable connection",
          status: connection ? connection.status : "missing",
          detail: connection ? "Connection ##{connection.id} is mapped to #{@employer.organization.name}." : "Create a Vitable integration connection before remote employer provisioning."
        ),
        EmployerProvisioningPreflightCheckDto.new(
          label: "API credentials",
          status: connection&.credentials_present? ? "ready" : "needs_credentials",
          detail: connection&.credentials_present? ? "#{connection.api_key_reference} is available to Rails." : "Set #{connection&.api_key_reference || "VITABLE_CONNECT_API_KEY"} before live employer provisioning."
        ),
        EmployerProvisioningPreflightCheckDto.new(
          label: "Legal entity",
          status: [ payload.name, payload.legal_name, payload.ein, payload.email ].all?(&:present?) ? "ready" : "blocked",
          detail: [ payload.legal_name, payload.ein, payload.email ].compact_blank.to_sentence.presence || "Name, legal name, EIN, and billing email are required for create."
        ),
        EmployerProvisioningPreflightCheckDto.new(
          label: "Physical address",
          status: [ payload.address_line_1, payload.city, payload.state, payload.zipcode ].all?(&:present?) ? "ready" : "blocked",
          detail: [ payload.address_line_1, payload.city, payload.state, payload.zipcode ].compact_blank.join(", ").presence || "A non-remote employer address is required for create."
        ),
        EmployerProvisioningPreflightCheckDto.new(
          label: "Eligibility policy",
          status: [ payload.eligibility_classification, payload.eligibility_waiting_period ].all?(&:present?) ? "ready" : "blocked",
          detail: [ payload.eligibility_classification, payload.eligibility_waiting_period ].compact_blank.join(" · ").presence || "Classification and waiting period are required before eligibility policy creation."
        ),
        EmployerProvisioningPreflightCheckDto.new(
          label: "Provisioning packet",
          status: latest_packet ? latest_packet.status : "pending",
          detail: latest_packet ? "Generated #{latest_packet.packet_id} by #{latest_packet.requested_by}." : "Generate a packet before submitting to Vitable."
        ),
        EmployerProvisioningPreflightCheckDto.new(
          label: "Submit readiness",
          status: holdbacks.any? ? "blocked" : "ready",
          detail: holdbacks.any? ? "#{holdbacks.count} blocking fields need attention before submit." : "Packet can be submitted once credentials are configured."
        )
      ]
    end

    def eligibility_policy
      @employer&.settings.to_h.fetch("vitable_eligibility_policy", nil).to_h
    end

    def eligibility_policy_status
      return "needs_review" if eligibility_policy.fetch("status", nil) == "endpoint_unavailable"
      return "ready" if eligibility_policy.present?

      "pending"
    end

    def eligibility_policy_value
      return "Demo unavailable" if eligibility_policy.fetch("status", nil) == "endpoint_unavailable"
      return "Synced" if eligibility_policy.present?

      "Create pending"
    end
  end
end
