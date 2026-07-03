module Vitable
  EmbeddedSessionsCenterDto = Data.define(
    :employer,
    :connection_id,
    :connection_status,
    :credentials_present,
    :api_key_reference,
    :metrics,
    :preflight_checks,
    :employees,
    :holdbacks,
    :latest_packet,
    :token_runs,
    :request_logs,
    :docs_url,
    :ruby_docs_url
  ) do
    def generated?
      latest_packet.present?
    end
  end
end
