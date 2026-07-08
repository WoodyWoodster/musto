module Vitable
  EmployerProvisioningCenterDto = Data.define(
    :employer,
    :connection_id,
    :connection_status,
    :credentials_present,
    :api_key_reference,
    :remote_employer_id,
    :metrics,
    :preflight_checks,
    :payload,
    :holdbacks,
    :latest_packet,
    :sync_runs,
    :request_logs,
    :docs_url,
    :ruby_docs_url,
    :onboarding_docs_url
  ) do
    def generated?
      latest_packet.present?
    end

    def submittable?
      generated? &&
        latest_packet.status == "ready" &&
        latest_packet.holdback_count.zero? &&
        credentials_present &&
        packet_current?
    end

    def packet_current?
      return false unless generated?

      latest_packet.mode == (remote_employer_id.present? ? "update_settings" : "create")
    end
  end
end
