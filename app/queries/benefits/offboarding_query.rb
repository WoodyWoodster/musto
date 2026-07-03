module Benefits
  class OffboardingQuery
    def initialize(employer_repository: Employers::EmployerRepository.new)
      @employer = employer_repository.first_for_operations
      @repository = OffboardingRepository.new(employer: @employer)
    end

    def call
      events = @repository.coverage_events
      coverage_lines = @repository.coverage_lines
      packet_payload = @repository.latest_packet

      OffboardingCenterDto.new(
        employer: Operations::EmployerContextDto.from_record(@employer),
        metrics: metrics(events, coverage_lines, packet_payload),
        events: events.map { |event| OffboardingEventDto.from_record(event) },
        coverage_lines: coverage_lines.map { |line| OffboardingCoverageLineDto.from_hash(line) },
        issues: @repository.issues.map { |issue| OffboardingIssueDto.from_hash(issue) },
        packet: packet_payload.present? ? OffboardingPacketDto.from_hash(packet_payload) : nil,
        packet_lines: packet_payload.to_h.fetch("terminations", []).map { |line| OffboardingCoverageLineDto.from_hash(line) },
        packet_holdbacks: packet_payload.to_h.fetch("holdbacks", []).map { |issue| OffboardingIssueDto.from_hash(issue) }
      )
    end

    private

    def metrics(events, coverage_lines, packet_payload)
      ready_lines = coverage_lines.count { |line| line.fetch("status") == "ready" }
      holdbacks = @repository.issues.count + coverage_lines.count { |line| line.fetch("status") != "ready" }

      [
        OffboardingMetricDto.new(label: "Termination events", value: events.count, hint: "with coverage impact", status: events.any? ? "needs_review" : "ready", accent: "bg-rose-500", format: "number"),
        OffboardingMetricDto.new(label: "Coverage lines", value: coverage_lines.count, hint: "#{ready_lines} ready for Vitable", status: ready_lines.positive? ? "ready" : "needs_review", accent: "bg-cyan-500", format: "number"),
        OffboardingMetricDto.new(label: "Holdbacks", value: holdbacks, hint: "blocking termination packet", status: holdbacks.positive? ? "needs_review" : "ready", accent: "bg-amber-500", format: "number"),
        OffboardingMetricDto.new(label: "Packet", value: packet_payload.to_h.fetch("status", "Not generated").humanize, hint: "coverage termination packet", status: packet_payload.to_h.fetch("status", "pending"), accent: "bg-indigo-500", format: "text")
      ]
    end
  end
end
