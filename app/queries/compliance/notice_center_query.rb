module Compliance
  class NoticeCenterQuery
    def initialize(employer_repository: Employers::EmployerRepository.new)
      @employer = employer_repository.first_for_operations
      @repository = NoticeRepository.new(employer: @employer)
    end

    def call
      notices = @repository.notices.to_a
      issues = @repository.issues
      packet_payload = @repository.latest_packet

      NoticeCenterDto.new(
        employer: Operations::EmployerContextDto.from_record(@employer),
        metrics: metrics(notices, issues, packet_payload),
        notices: notices.map { |notice| NoticeDto.from_record(notice) },
        issues: issues.map { |issue| NoticeIssueDto.from_hash(issue) },
        packet: packet_payload.present? ? NoticePacketDto.from_hash(packet_payload) : nil,
        packet_lines: packet_payload.to_h.fetch("notices", []).map { |line| NoticePacketLineDto.from_hash(line) },
        packet_holdbacks: packet_payload.to_h.fetch("holdbacks", []).map { |issue| NoticeIssueDto.from_hash(issue) },
        packet_payload:
      )
    end

    private

    def metrics(notices, issues, packet_payload)
      open_notices = notices.count(&:open?)
      amount_cents = notices.select(&:open?).sum(&:amount_cents)
      due_soon = notices.count(&:due_soon?)
      high_severity = issues.count { |issue| issue.fetch("severity").in?(%w[critical high]) }

      [
        NoticeMetricDto.new(label: "Open notices", value: open_notices, hint: "#{notices.count} total notices", status: open_notices.positive? ? "needs_review" : "ready", accent: "bg-rose-500", format: "number"),
        NoticeMetricDto.new(label: "Due soon", value: due_soon, hint: "inside 10 days", status: due_soon.positive? ? "due_soon" : "ready", accent: "bg-amber-500", format: "number"),
        NoticeMetricDto.new(label: "Amount at risk", value: amount_cents, hint: "#{high_severity} urgent holdbacks", status: amount_cents.positive? ? "needs_review" : "ready", accent: "bg-indigo-500", format: "money"),
        NoticeMetricDto.new(label: "Packet", value: packet_payload.to_h.fetch("status", "Not generated").humanize, hint: "agency response packet", status: packet_payload.to_h.fetch("status", "pending"), accent: "bg-cyan-500", format: "text")
      ]
    end
  end
end
