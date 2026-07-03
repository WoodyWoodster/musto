module TimeOff
  class CommandCenterQuery
    def initialize(employer_repository: Employers::EmployerRepository.new)
      @employer = employer_repository.first_for_operations
      @repository = TimeOffRepository.new(employer: @employer)
    end

    def call
      policies = @repository.policies.to_a
      requests = @repository.requests.to_a
      request_dtos = requests.map { |request| RequestDto.from_record(request) }
      balance_dtos = balances(@repository.employees.to_a, policies)

      CommandCenterDto.new(
        employer: Operations::EmployerContextDto.from_record(@employer),
        metrics: metrics(policies, request_dtos, balance_dtos),
        policies: policies.map { |policy| PolicyDto.from_record(policy) },
        balances: balance_dtos,
        requests: request_dtos,
        calendar_blocks: calendar_blocks(requests)
      )
    end

    private

    def balances(employees, policies)
      employees.map do |employee|
        EmployeeBalanceDto.from_employee(employee, policies, employee.time_off_requests.to_a)
      end
    end

    def metrics(policies, requests, balances)
      pending_requests = requests.count(&:requested?)
      approved_hours = requests.select(&:approved?).sum(&:hours)
      upcoming_count = requests.count { |request| request.starts_on >= Date.current && !request.denied? }
      at_risk_count = balances.count(&:needs_attention?)

      [
        MetricDto.new(
          label: "Pending requests",
          value: pending_requests,
          hint: pending_requests.positive? ? "Waiting on manager review" : "Queue is clear",
          status: pending_requests.positive? ? "needs_review" : "ready",
          accent: "bg-cyan-500"
        ),
        MetricDto.new(
          label: "Approved hours",
          value: approved_hours,
          hint: "Current year approved leave",
          status: approved_hours.positive? ? "approved" : "pending",
          accent: "bg-emerald-500"
        ),
        MetricDto.new(
          label: "Upcoming blocks",
          value: upcoming_count,
          hint: "Scheduled or requested future leave",
          status: upcoming_count.positive? ? "in_progress" : "ready",
          accent: "bg-indigo-500"
        ),
        MetricDto.new(
          label: "Policy coverage",
          value: policies.count,
          hint: "#{at_risk_count} balances need attention",
          status: at_risk_count.positive? ? "needs_review" : "ready",
          accent: "bg-amber-500"
        )
      ]
    end

    def calendar_blocks(requests)
      requests
        .select { |request| request.starts_on >= Date.current && request.status != "denied" }
        .first(12)
        .map { |request| CalendarBlockDto.from_record(request) }
    end
  end
end
