module TimeOff
  class AccrualLedgerQuery
    def initialize(employer_repository: Employers::EmployerRepository.new)
      @employer = employer_repository.first_for_operations
      @repository = AccrualRepository.new(employer: @employer)
    end

    def call
      policies = @repository.policies.to_a
      employees = @repository.employees.to_a
      accruals = @repository.accruals.to_a
      requests = @repository.requests.to_a
      balances = employees.map { |employee| AccrualBalanceDto.from_employee(employee, policies, accruals, requests) }
      accrual_lines = accruals.first(40).map { |accrual| AccrualLineDto.from_record(accrual) }
      packet_payload = @repository.latest_packet

      AccrualCenterDto.new(
        employer: Operations::EmployerContextDto.from_record(@employer),
        metrics: metrics(accruals, requests, balances, packet_payload),
        balances:,
        accruals: accrual_lines,
        issues: issues(balances, accruals, requests),
        packet: packet_payload.present? ? AccrualPacketDto.from_hash(packet_payload) : nil,
        packet_lines: packet_payload.to_h.fetch("lines", []).map { |line| AccrualPacketLineDto.from_hash(line) },
        packet_holdbacks: packet_payload.to_h.fetch("holdbacks", []).map { |line| AccrualIssueDto.from_hash(line) }
      )
    end

    private

    def metrics(accruals, requests, balances, packet_payload)
      pending_accruals = accruals.count { |accrual| accrual.status == "pending" }
      approved_hours = accruals.select { |accrual| accrual.status == "approved" }.sum(&:hours)
      usage_hours = requests.select { |request| request.status == "approved" }.sum(&:hours)
      risk_count = balances.count(&:needs_attention?)

      [
        AccrualMetricDto.new(label: "Approved accruals", value: approved_hours, hint: "#{accruals.count} ledger entries", status: approved_hours.positive? ? "ready" : "pending", accent: "bg-emerald-500", format: "hours"),
        AccrualMetricDto.new(label: "Pending credits", value: pending_accruals, hint: "need approval before payroll", status: pending_accruals.positive? ? "needs_review" : "ready", accent: "bg-amber-500", format: "number"),
        AccrualMetricDto.new(label: "Approved usage", value: usage_hours, hint: "PTO hours to export", status: usage_hours.positive? ? "approved" : "pending", accent: "bg-violet-500", format: "hours"),
        AccrualMetricDto.new(label: "Payroll packet", value: packet_payload.to_h.fetch("status", "Not generated").humanize, hint: "#{risk_count} balances need review", status: packet_payload.to_h.fetch("status", "pending"), accent: "bg-cyan-500", format: "text")
      ]
    end

    def issues(balances, accruals, requests)
      items = []
      balances.select(&:needs_attention?).each do |balance|
        items << AccrualIssueDto.new(employee_id: balance.employee_id, employee_name: balance.employee_name, policy_name: "All policies", status: balance.status, reason_code: "balance_review", reason: "#{balance.employee_name} has #{balance.remaining_hours} approved hours remaining with #{balance.pending_accrual_hours} pending credits.")
      end
      accruals.select { |accrual| accrual.status == "pending" }.first(8).each do |accrual|
        items << AccrualIssueDto.new(employee_id: accrual.employee_id, employee_name: accrual.employee.full_name, policy_name: accrual.time_off_policy.name, status: "needs_review", reason_code: "pending_accrual", reason: "Pending #{accrual.hours}h accrual for #{accrual.period_start_on.strftime('%b %Y')}.")
      end
      requests.select { |request| request.status == "requested" }.first(8).each do |request|
        items << AccrualIssueDto.new(employee_id: request.employee_id, employee_name: request.employee.full_name, policy_name: request.time_off_policy.name, status: "needs_review", reason_code: "pending_time_off_request", reason: "Pending #{request.hours}h request overlaps payroll readiness.")
      end
      items
    end
  end
end
