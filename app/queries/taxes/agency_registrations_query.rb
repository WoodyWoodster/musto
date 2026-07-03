module Taxes
  class AgencyRegistrationsQuery
    def initialize(employer_repository: Employers::EmployerRepository.new)
      @employer = employer_repository.first_for_operations
      @repository = AgencyRegistrationRepository.new(employer: @employer)
    end

    def call
      registrations = @repository.registrations.to_a
      issues = @repository.issues
      packet_payload = @repository.latest_packet

      AgencyRegistrationCenterDto.new(
        employer: Operations::EmployerContextDto.from_record(@employer),
        metrics: metrics(registrations, issues, packet_payload),
        registrations: registrations.map { |registration| AgencyRegistrationDto.from_record(registration) },
        issues: issues.map { |issue| AgencyRegistrationIssueDto.from_hash(issue) },
        packet: packet_payload.present? ? AgencyRegistrationPacketDto.from_hash(packet_payload) : nil,
        packet_lines: packet_payload.to_h.fetch("registrations", []).map { |line| AgencyRegistrationPacketLineDto.from_hash(line) },
        packet_holdbacks: packet_payload.to_h.fetch("holdbacks", []).map { |issue| AgencyRegistrationIssueDto.from_hash(issue) },
        packet_payload:
      )
    end

    private

    def metrics(registrations, issues, packet_payload)
      ready_count = registrations.count { |registration| registration.status.in?(%w[submitted registered]) }
      due_soon_count = registrations.count(&:due_soon?)
      blocked_count = issues.count { |issue| issue.fetch("severity") == "high" }

      [
        AgencyRegistrationMetricDto.new(label: "Registrations", value: registrations.count, hint: "#{ready_count} submitted or registered", status: ready_count == registrations.count ? "ready" : "needs_review", accent: "bg-cyan-500", format: "number"),
        AgencyRegistrationMetricDto.new(label: "Due soon", value: due_soon_count, hint: "inside 14 days", status: due_soon_count.positive? ? "due_soon" : "ready", accent: "bg-amber-500", format: "number"),
        AgencyRegistrationMetricDto.new(label: "Holdbacks", value: issues.count, hint: "#{blocked_count} high severity", status: issues.any? ? "needs_review" : "ready", accent: "bg-rose-500", format: "number"),
        AgencyRegistrationMetricDto.new(label: "Packet", value: packet_payload.to_h.fetch("status", "Not generated").humanize, hint: "registration audit packet", status: packet_payload.to_h.fetch("status", "pending"), accent: "bg-indigo-500", format: "text")
      ]
    end
  end
end
