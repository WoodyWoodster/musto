module WorkersComp
  class CenterQuery
    def initialize(employer_repository: Employers::EmployerRepository.new)
      @employer = employer_repository.first_for_operations
      @repository = CoverageRepository.new(employer: @employer)
    end

    def call
      policy = @repository.current_policy
      exposures = @repository.exposures
      claim_records = @repository.claims.to_a
      issues = @repository.issues
      packet_payload = @repository.latest_packet

      CenterDto.new(
        employer: Operations::EmployerContextDto.from_record(@employer),
        policy: PolicyDto.from_record(policy),
        metrics: metrics(policy, exposures, claim_records, issues),
        exposures: exposures.map { |line| ExposureDto.from_hash(line) },
        claims: claim_records.map { |claim| ClaimDto.from_record(claim) },
        issues: issues.map { |issue| IssueDto.from_hash(issue) },
        packet: packet_payload.present? ? AuditPacketDto.from_hash(packet_payload) : nil,
        packet_lines: packet_payload.to_h.fetch("lines", []).map { |line| ExposureDto.from_hash(line) },
        packet_claims: packet_payload.to_h.fetch("claims", []).map { |claim| AuditClaimDto.from_hash(claim) },
        packet_holdbacks: packet_payload.to_h.fetch("holdbacks", []).map { |issue| IssueDto.from_hash(issue) },
        packet_payload:
      )
    end

    private

    def metrics(policy, exposures, claims, issues)
      payroll_basis_cents = exposures.sum { |line| line.fetch("payroll_cents") }
      premium_cents = exposures.sum { |line| line.fetch("estimated_premium_cents") }
      open_claims = claims.count(&:open?)

      [
        MetricDto.new(label: "Coverage", value: policy&.status&.humanize || "Missing", hint: policy ? "#{policy.coverage_end_on.strftime("%b %-d, %Y")} policy end" : "policy setup required", status: policy&.coverage_active? ? "active" : "needs_review", accent: "bg-emerald-500", format: "text"),
        MetricDto.new(label: "Payroll exposure", value: payroll_basis_cents, hint: "#{exposures.count} class-code groups", status: payroll_basis_cents.positive? ? "ready" : "needs_review", accent: "bg-indigo-500", format: "money"),
        MetricDto.new(label: "Est. premium", value: premium_cents, hint: "modeled from class-code rates", status: premium_cents.positive? ? "estimated" : "needs_review", accent: "bg-cyan-500", format: "money"),
        MetricDto.new(label: "Open claims", value: open_claims, hint: "#{issues.count} audit issues", status: open_claims.positive? ? "needs_review" : "ready", accent: "bg-rose-500", format: "number")
      ]
    end
  end
end
