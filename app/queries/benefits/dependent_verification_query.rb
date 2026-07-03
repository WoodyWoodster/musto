module Benefits
  class DependentVerificationQuery
    def initialize(employer_repository: Employers::EmployerRepository.new)
      @employer = employer_repository.first_for_operations
      @repository = DependentVerificationRepository.new(employer: @employer)
    end

    def call
      dependents = @repository.dependents.to_a
      dependent_dtos = dependents.map { |dependent| DependentVerificationDependentDto.from_record(dependent, verification: @repository.primary_verification(dependent)) }
      verification_dtos = @repository.verifications.first(30).map { |verification| DependentVerificationRecordDto.from_record(verification) }
      packet_payload = @repository.latest_packet

      DependentVerificationCenterDto.new(
        employer: Operations::EmployerContextDto.from_record(@employer),
        metrics: metrics(dependent_dtos, verification_dtos, packet_payload),
        dependents: dependent_dtos,
        verifications: verification_dtos,
        issues: issues(dependent_dtos),
        packet: packet_payload.present? ? DependentVerificationPacketDto.from_hash(packet_payload) : nil,
        packet_lines: packet_payload.to_h.fetch("dependents", []).map { |line| DependentVerificationPacketLineDto.from_hash(line) },
        packet_holdbacks: packet_payload.to_h.fetch("holdbacks", []).map { |line| DependentVerificationIssueDto.from_hash(line) }
      )
    end

    private

    def metrics(dependents, verifications, packet_payload)
      ready_count = dependents.count(&:ready?)
      review_count = verifications.count(&:reviewable?)
      holdback_count = dependents.count { |dependent| !dependent.ready? }

      [
        DependentVerificationMetricDto.new(label: "Dependents", value: dependents.count, hint: "#{ready_count} ready for Vitable", status: dependents.any? ? "ready" : "empty", accent: "bg-cyan-500", format: "number"),
        DependentVerificationMetricDto.new(label: "Review queue", value: review_count, hint: "complete docs awaiting review", status: review_count.positive? ? "needs_review" : "ready", accent: "bg-amber-500", format: "number"),
        DependentVerificationMetricDto.new(label: "Holdbacks", value: holdback_count, hint: "blocked dependent records", status: holdback_count.positive? ? "needs_review" : "ready", accent: "bg-rose-500", format: "number"),
        DependentVerificationMetricDto.new(label: "Packet", value: packet_payload.to_h.fetch("status", "Not generated").humanize, hint: "dependent verification packet", status: packet_payload.to_h.fetch("status", "pending"), accent: "bg-indigo-500", format: "text")
      ]
    end

    def issues(dependents)
      dependents.reject(&:ready?).map do |dependent|
        DependentVerificationIssueDto.new(
          dependent_id: dependent.dependent_id,
          dependent_name: dependent.dependent_name,
          employee_name: dependent.employee_name,
          status: dependent.readiness_status,
          reason_code: dependent.verification_status == "missing" ? "missing_verification" : dependent.verification_status,
          reason: dependent.readiness_reason
        )
      end
    end
  end
end
