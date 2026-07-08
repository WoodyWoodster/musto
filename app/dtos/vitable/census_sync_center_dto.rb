module Vitable
  CensusSyncCenterDto = Data.define(
    :employer,
    :connection_id,
    :connection_status,
    :credentials_present,
    :api_key_reference,
    :remote_employer_id,
    :metrics,
    :preflight_checks,
    :employees,
    :holdbacks,
    :latest_manifest,
    :latest_submission,
    :latest_verification,
    :sync_runs,
    :request_logs,
    :endpoint_path,
    :docs_url,
    :ruby_docs_url
  ) do
    def generated?
      latest_manifest.present?
    end

    def submittable?
      generated? && latest_manifest.ready_count.positive?
    end
  end
end
