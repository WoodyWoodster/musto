module Benefits
  class PlanAdministrationQuery
    def initialize(employer_repository: Employers::EmployerRepository.new)
      @employer = employer_repository.first_for_operations
      @repository = PlanAdministrationRepository.new(employer: @employer)
    end

    def call
      plans = @repository.plans.map { |plan| plan_dto(plan) }
      packet_payload = @repository.latest_packet

      PlanAdministrationCenterDto.new(
        employer: Operations::EmployerContextDto.from_record(@employer),
        metrics: metrics(plans, packet_payload),
        plans:,
        issues: plans.flat_map(&:readiness_issues),
        packet: packet_payload.present? ? PlanCatalogPacketDto.from_hash(packet_payload) : nil,
        packet_lines: packet_payload.to_h.fetch("plans", []).map { |line| PlanCatalogLineDto.from_hash(line) },
        packet_holdbacks: packet_payload.to_h.fetch("holdbacks", []).map { |line| PlanReadinessIssueDto.from_hash(line) }
      )
    end

    private

    def plan_dto(plan)
      PlanDesignDto.from_record(plan, readiness_issues: @repository.readiness_issues(plan))
    end

    def metrics(plans, packet_payload)
      published_count = plans.count { |plan| plan.review_status == "published" }
      issue_count = plans.sum { |plan| plan.readiness_issues.count }
      packet_status = packet_payload.to_h.fetch("status", "pending")

      [
        PlanAdminMetricDto.new(label: "Plan catalog", value: plans.count, hint: "#{published_count} published", status: plans.any? ? "ready" : "empty", accent: "bg-cyan-500", format: "number"),
        PlanAdminMetricDto.new(label: "Monthly premium", value: plans.sum(&:monthly_premium_cents), hint: "modeled local catalog", status: "ready", accent: "bg-emerald-500", format: "money"),
        PlanAdminMetricDto.new(label: "Readiness issues", value: issue_count, hint: "blocking catalog sync", status: issue_count.positive? ? "needs_review" : "ready", accent: "bg-amber-500", format: "number"),
        PlanAdminMetricDto.new(label: "Packet", value: packet_status.humanize, hint: packet_payload.present? ? "latest Vitable catalog packet" : "generate before sync", status: packet_status, accent: "bg-indigo-500", format: "text")
      ]
    end
  end
end
