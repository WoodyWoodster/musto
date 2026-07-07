module Benefits
  class PlanAdministrationQuery
    def initialize(employer_repository: Employers::EmployerRepository.new)
      @employer = employer_repository.first_for_operations
      @repository = PlanAdministrationRepository.new(employer: @employer)
    end

    def call
      plans = @repository.plans.map { |plan| plan_dto(plan) }
      packet_payload = @repository.latest_packet
      remote_snapshot_payload = @repository.latest_remote_snapshot.to_h
      connection = @repository.connection

      PlanAdministrationCenterDto.new(
        employer: Operations::EmployerContextDto.from_record(@employer),
        connection_id: connection&.id,
        connection_status: connection&.status || "missing",
        credentials_present: connection&.credentials_present? || false,
        api_key_reference: connection&.api_key_reference || "VITABLE_CONNECT_API_KEY",
        metrics: metrics(plans, packet_payload),
        plans:,
        issues: plans.flat_map(&:readiness_issues),
        packet: packet_payload.present? ? PlanCatalogPacketDto.from_hash(packet_payload) : nil,
        packet_lines: packet_payload.to_h.fetch("plans", []).map { |line| PlanCatalogLineDto.from_hash(line) },
        packet_holdbacks: packet_payload.to_h.fetch("holdbacks", []).map { |line| PlanReadinessIssueDto.from_hash(line) },
        remote_snapshot: VitablePlanCatalogSnapshotDto.from_hash(remote_snapshot_payload),
        mapped_plans: remote_snapshot_payload.fetch("mapped_plans", []).map { |line| VitablePlanMappingDto.from_hash(line) },
        mapping_issues: mapping_issues(remote_snapshot_payload),
        mapping_runs: @repository.mapping_runs.map { |sync| Operations::SyncRunDto.from_record(sync) },
        request_logs: @repository.request_logs.map { |log| Operations::ApiRequestLogDto.from_record(log) }
      )
    end

    private

    def plan_dto(plan)
      PlanDesignDto.from_record(plan, readiness_issues: @repository.readiness_issues(plan))
    end

    def metrics(plans, packet_payload)
      published_count = plans.count { |plan| plan.review_status == "published" }
      mapped_count = plans.count { |plan| plan.vitable_id.present? }
      issue_count = plans.sum { |plan| plan.readiness_issues.count }
      packet_status = packet_payload.to_h.fetch("status", "pending")

      [
        PlanAdminMetricDto.new(label: "Plan catalog", value: plans.count, hint: "#{published_count} published", status: plans.any? ? "ready" : "empty", accent: "bg-cyan-500", format: "number"),
        PlanAdminMetricDto.new(label: "Remote mappings", value: mapped_count, hint: "plans mapped to Vitable IDs", status: mapped_count == plans.count && plans.any? ? "ready" : "needs_review", accent: "bg-violet-500", format: "number"),
        PlanAdminMetricDto.new(label: "Monthly premium", value: plans.sum(&:monthly_premium_cents), hint: "modeled local catalog", status: "ready", accent: "bg-emerald-500", format: "money"),
        PlanAdminMetricDto.new(label: "Readiness issues", value: issue_count, hint: "blocking catalog sync", status: issue_count.positive? ? "needs_review" : "ready", accent: "bg-amber-500", format: "number"),
        PlanAdminMetricDto.new(label: "Packet", value: packet_status.humanize, hint: packet_payload.present? ? "latest Vitable catalog packet" : "generate before sync", status: packet_status, accent: "bg-indigo-500", format: "text")
      ]
    end

    def mapping_issues(snapshot_payload)
      [
        *snapshot_payload.fetch("unmatched_remote_plans", []).map { |line| VitablePlanMappingIssueDto.unmatched_remote(line) },
        *snapshot_payload.fetch("unmatched_local_plans", []).map { |line| VitablePlanMappingIssueDto.unmatched_local(line) },
        *snapshot_payload.fetch("ambiguous_remote_plans", []).map { |line| VitablePlanMappingIssueDto.ambiguous_remote(line) }
      ]
    end
  end
end
