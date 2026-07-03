module Compensation
  class ChangesQuery
    def initialize(employer_repository: Employers::EmployerRepository.new)
      @employer = employer_repository.first_for_operations
      @repository = ChangesRepository.new(employer: @employer)
    end

    def call
      change_dtos = @repository.changes.map { |change| ChangeDto.from_record(change) }
      packet_payload = @repository.packets.first
      packet = packet_payload.present? ? ChangePacketDto.from_hash(packet_payload) : nil
      packet_lines = packet_payload.to_h.fetch("changes", []).map { |payload| ChangePacketLineDto.from_hash(payload) }
      packet_holdbacks = packet_payload.to_h.fetch("holdbacks", []).map { |payload| ChangePacketHoldbackDto.from_hash(payload) }

      ChangeCenterDto.new(
        employer: Operations::EmployerContextDto.from_record(@employer),
        metrics: metrics(change_dtos, packet),
        changes: change_dtos,
        reviewable_changes: change_dtos.select(&:reviewable?),
        approved_changes: change_dtos.select(&:approved?),
        applied_changes: change_dtos.select(&:applied?),
        packet:,
        packet_lines:,
        packet_holdbacks:,
        payroll_run: @repository.payroll_run
      )
    end

    private

    def metrics(changes, packet)
      [
        MetricDto.new(label: "Open changes", value: changes.count { |change| change.status.in?(%w[draft submitted approved]) }, hint: "awaiting review or apply", status: changes.any?(&:reviewable?) ? "needs_review" : "ready", accent: "bg-fuchsia-500", format: "number"),
        MetricDto.new(label: "Recurring delta", value: recurring_delta(changes), hint: "annual base pay movement", status: recurring_delta(changes).positive? ? "needs_review" : "ready", accent: "bg-indigo-500", format: "money"),
        MetricDto.new(label: "One-time pay", value: one_time_delta(changes), hint: "bonus and correction exposure", status: one_time_delta(changes).positive? ? "needs_review" : "ready", accent: "bg-emerald-500", format: "money"),
        MetricDto.new(label: "Latest packet", value: packet&.status&.humanize || "Not generated", hint: packet ? "#{packet.change_count} payroll-ready lines" : "generate after approvals", status: packet&.status || "pending", accent: "bg-cyan-500", format: "text")
      ]
    end

    def recurring_delta(changes)
      changes.select { |change| change.change_type.in?(CompensationChange::BASE_PAY_CHANGE_TYPES) && !change.applied? }.sum(&:delta_cents)
    end

    def one_time_delta(changes)
      changes.select { |change| change.change_type.in?(CompensationChange::ONE_TIME_CHANGE_TYPES) && !change.applied? }.sum(&:delta_cents)
    end
  end
end
