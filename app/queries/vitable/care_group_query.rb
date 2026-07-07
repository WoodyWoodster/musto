module Vitable
  class CareGroupQuery
    def initialize(employer_repository: Employers::EmployerRepository.new)
      @employer = employer_repository.first_for_operations
      @repository = CareGroupRepository.new(employer: @employer)
    end

    def call
      group_packet_payload = @repository.latest_group_packet
      member_manifest_payload = @repository.latest_member_manifest
      display_group_packet = group_packet_payload.presence || @repository.preview_group_packet(requested_by: "preview")
      group_packet = group_packet_payload.present? ? CareGroupPacketDto.from_hash(group_packet_payload) : nil
      member_manifest = member_manifest_payload.present? ? CareMemberSyncManifestDto.from_hash(member_manifest_payload) : nil
      members = member_manifest_payload.to_h.fetch("members", []).map { |payload| CareMemberSyncMemberDto.from_hash(payload) }
      holdbacks = member_manifest_payload.to_h.fetch("holdbacks", []).map { |payload| CareMemberSyncHoldbackDto.from_hash(payload) }
      connection = @repository.connection
      roster = @repository.employees.to_a

      CareGroupCenterDto.new(
        employer: Operations::EmployerContextDto.from_record(@employer),
        connection_id: connection&.id,
        connection_status: connection&.status || "missing",
        credentials_present: connection&.credentials_present? || false,
        api_key_reference: connection&.api_key_reference || "VITABLE_CONNECT_API_KEY",
        remote_group_id: @repository.remote_group_id,
        metrics: metrics(roster, group_packet, member_manifest, holdbacks, connection),
        preflight_checks: preflight_checks(roster, display_group_packet, group_packet, member_manifest, holdbacks, connection),
        group_packet:,
        member_manifest:,
        members:,
        holdbacks:,
        sync_runs: @repository.sync_runs.map { |sync| Operations::SyncRunDto.from_record(sync) },
        request_logs: @repository.request_logs.map { |log| Operations::ApiRequestLogDto.from_record(log) },
        member_sync_request: @repository.latest_member_sync_request.to_h,
        group_endpoint_path: "/v1/groups",
        member_sync_endpoint_path: "/v1/groups/:group_id/members/sync",
        docs_url: "https://developer.vitablehealth.com/",
        ruby_docs_url: "https://developer.vitablehealth.com/api/ruby"
      )
    end

    private

    def metrics(roster, group_packet, member_manifest, holdbacks, connection)
      last_run = @repository.sync_runs.first

      [
        CareGroupMetricDto.new(label: "Care group", value: @repository.remote_group_id.presence || "Create pending", hint: "Vitable group identifier", status: @repository.remote_group_id.present? ? "ready" : "pending", accent: "bg-indigo-500", format: "text"),
        CareGroupMetricDto.new(label: "Members", value: roster.count, hint: "active employees reviewed", status: roster.any? ? "ready" : "empty", accent: "bg-cyan-500", format: "number"),
        CareGroupMetricDto.new(label: "Ready members", value: member_manifest&.ready_count || 0, hint: "complete group member payloads", status: (member_manifest&.ready_count || 0).positive? ? "ready" : "needs_review", accent: "bg-emerald-500", format: "number"),
        CareGroupMetricDto.new(label: "Plan holdbacks", value: member_manifest&.remote_plan_missing_count || 0, hint: "remote plan IDs required by Vitable", status: (member_manifest&.remote_plan_missing_count || 0).positive? ? "blocked" : "ready", accent: "bg-rose-500", format: "number"),
        CareGroupMetricDto.new(label: "Last activity", value: last_run&.status&.humanize || "Not sent", hint: connection ? "credential-aware group sync run" : "no Vitable connection", status: last_run&.status || "pending", accent: "bg-violet-500", format: "text")
      ]
    end

    def preflight_checks(roster, display_group_packet, group_packet, member_manifest, holdbacks, connection)
      [
        CareGroupPreflightCheckDto.new(
          label: "Vitable connection",
          status: connection ? connection.status : "missing",
          detail: connection ? "Connection ##{connection.id} is mapped to #{@employer.organization.name}." : "Create a Vitable integration connection before Embedded Care group sync."
        ),
        CareGroupPreflightCheckDto.new(
          label: "API credentials",
          status: connection&.credentials_present? ? "ready" : "needs_credentials",
          detail: connection&.credentials_present? ? "#{connection.api_key_reference} is available to Rails." : "Set #{connection&.api_key_reference || "VITABLE_CONNECT_API_KEY"} before live group sync."
        ),
        CareGroupPreflightCheckDto.new(
          label: "Group profile",
          status: display_group_packet.fetch("status"),
          detail: "#{display_group_packet.dig("api_payload", "name").presence || "Missing group name"} · #{display_group_packet.dig("api_payload", "external_reference_id")}"
        ),
        CareGroupPreflightCheckDto.new(
          label: "Remote group ID",
          status: @repository.remote_group_id.present? ? "ready" : "pending",
          detail: @repository.remote_group_id.presence || "Create the Vitable group before submitting members."
        ),
        CareGroupPreflightCheckDto.new(
          label: "Remote plan IDs",
          status: holdbacks.any? { |holdback| holdback.reason_code == "missing_remote_plan_id" } ? "blocked" : "ready",
          detail: remote_plan_detail(member_manifest)
        ),
        CareGroupPreflightCheckDto.new(
          label: "Member required fields",
          status: holdbacks.any? ? "needs_review" : "ready",
          detail: holdbacks.any? ? "#{holdbacks.count} employees are missing member-sync fields." : "#{member_manifest&.ready_count || 0} employees have member-sync fields."
        ),
        CareGroupPreflightCheckDto.new(
          label: "Batch size",
          status: roster.count > CareGroupRepository::MAX_MEMBERS ? "blocked" : "ready",
          detail: "#{roster.count} of #{CareGroupRepository::MAX_MEMBERS} maximum members selected."
        ),
        CareGroupPreflightCheckDto.new(
          label: "Latest packets",
          status: group_packet || member_manifest ? "ready" : "pending",
          detail: latest_packet_detail(group_packet, member_manifest)
        )
      ]
    end

    def remote_plan_detail(member_manifest)
      return "Generate a member manifest to inspect plan mappings." unless member_manifest
      return "All ready members have remote plan IDs." if member_manifest.remote_plan_missing_count.zero?

      "#{member_manifest.remote_plan_missing_count} members are blocked until plans have Vitable IDs."
    end

    def latest_packet_detail(group_packet, member_manifest)
      details = []
      details << "Group #{group_packet.packet_id}" if group_packet
      details << "Members #{member_manifest.manifest_id}" if member_manifest
      details.presence&.join(" · ") || "Generate group and member packets before submitting."
    end
  end
end
