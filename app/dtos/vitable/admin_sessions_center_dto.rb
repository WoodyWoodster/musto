module Vitable
  AdminSessionsCenterDto = Data.define(
    :employer,
    :connection_id,
    :connection_status,
    :credentials_present,
    :api_key_reference,
    :remote_employer_id,
    :metrics,
    :preflight_checks,
    :widgets,
    :holdbacks,
    :latest_packet,
    :latest_issuance,
    :token_runs,
    :request_logs,
    :docs_url,
    :ruby_docs_url,
    :administration_docs_url,
    :widget_base_url
  ) do
    def generated?
      latest_packet.present?
    end

    def active_session?
      latest_issuance&.active? || false
    end
  end
end
