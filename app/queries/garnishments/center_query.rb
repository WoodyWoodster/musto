module Garnishments
  class CenterQuery
    def initialize(employer_repository: Employers::EmployerRepository.new)
      @employer = employer_repository.first_for_operations
      @repository = GarnishmentRepository.new(employer: @employer)
    end

    def call
      order_records = @repository.orders.to_a
      run = @repository.current_run
      issues = @repository.issues
      packet_payload = @repository.latest_packet

      CenterDto.new(
        employer: Operations::EmployerContextDto.from_record(@employer),
        payroll_run: Deductions::PayrollRunDto.from_record(run),
        metrics: metrics(order_records, issues, packet_payload, run),
        orders: order_records.map { |order| OrderDto.from_record(order, repository: @repository, payroll_run: run) },
        issues: issues.map { |issue| IssueDto.from_hash(issue) },
        packet: packet_payload.present? ? PacketDto.from_hash(packet_payload) : nil,
        packet_lines: packet_payload.to_h.fetch("lines", []).map { |line| PacketLineDto.from_hash(line) },
        packet_holdbacks: packet_payload.to_h.fetch("holdbacks", []).map { |issue| IssueDto.from_hash(issue) },
        agency_summaries: packet_payload.to_h.fetch("agencies", []).map { |agency| AgencySummaryDto.from_hash(agency) },
        packet_payload:
      )
    end

    private

    def metrics(orders, issues, packet_payload, run)
      active_count = orders.count(&:active?)
      ready_orders = run ? orders.count { |order| @repository.readiness_status_for(order, run) == "ready" } : 0
      total_withheld = run ? orders.select { |order| @repository.readiness_status_for(order, run) == "ready" }.sum { |order| @repository.estimated_amount_for(order, pay_date: run.pay_date) } : 0
      agency_count = orders.map(&:agency_name).compact_blank.uniq.count

      [
        MetricDto.new(label: "Active orders", value: active_count, hint: "#{orders.count} legal orders tracked", status: active_count.positive? ? "active" : "needs_review", accent: "bg-rose-500", format: "number"),
        MetricDto.new(label: "Ready to remit", value: ready_orders, hint: run ? "for #{run.pay_date.strftime("%b %-d")}" : "no payroll run available", status: ready_orders.positive? ? "ready" : "needs_review", accent: "bg-emerald-500", format: "number"),
        MetricDto.new(label: "Modeled withholding", value: total_withheld, hint: "agency remittance impact", status: total_withheld.positive? ? "withheld" : "pending", accent: "bg-indigo-500", format: "money"),
        MetricDto.new(label: "Agencies", value: packet_payload.to_h.dig("totals", "agency_count") || agency_count, hint: "#{issues.count} blockers open", status: issues.any? ? "needs_review" : "ready", accent: "bg-cyan-500", format: "number")
      ]
    end
  end
end
