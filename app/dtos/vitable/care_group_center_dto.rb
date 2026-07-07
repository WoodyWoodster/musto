module Vitable
  CareGroupCenterDto = Data.define(
    :employer,
    :connection_id,
    :connection_status,
    :credentials_present,
    :api_key_reference,
    :remote_group_id,
    :metrics,
    :preflight_checks,
    :group_packet,
    :member_manifest,
    :members,
    :holdbacks,
    :sync_runs,
    :request_logs,
    :member_sync_request,
    :group_endpoint_path,
    :member_sync_endpoint_path,
    :docs_url,
    :ruby_docs_url
  ) do
    def group_generated?
      group_packet.present?
    end

    def member_manifest_generated?
      member_manifest.present?
    end

    def group_submittable?
      group_generated? && group_packet.status == "ready"
    end

    def member_submittable?
      member_manifest_generated? && member_manifest.ready_count.positive?
    end
  end
end
