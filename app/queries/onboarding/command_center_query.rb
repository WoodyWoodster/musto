module Onboarding
  class CommandCenterQuery
    def initialize(employer_repository: Employers::EmployerRepository.new)
      @employer = employer_repository.first_for_operations
      @repository = CommandCenterRepository.new(employer: @employer)
    end

    def call
      readiness = @repository.employees.map { |employee| EmployeeReadinessDto.from_record(employee) }
      tasks = @repository.tasks.map { |task| TaskDto.from_record(task) }
      documents = @repository.documents.map { |document| DocumentDto.from_record(document) }

      CommandCenterDto.new(
        employer: Operations::EmployerContextDto.from_record(@employer),
        metrics: metrics(readiness, tasks, documents),
        readiness:,
        tasks:,
        documents:,
        lanes: lanes(tasks)
      )
    end

    private

    def metrics(readiness, tasks, documents)
      open_tasks = tasks.reject(&:complete?)
      overdue_tasks = open_tasks.count(&:overdue?)
      attention_documents = documents.count(&:attention?)
      ready_employees = readiness.count(&:ready?)

      [
        CommandMetricDto.new(
          label: "Ready employees",
          value: ready_employees,
          hint: "#{readiness.count} active employees reviewed",
          status: ready_employees.positive? ? "ready" : "needs_review",
          accent: "bg-emerald-500"
        ),
        CommandMetricDto.new(
          label: "Open tasks",
          value: open_tasks.count,
          hint: overdue_tasks.positive? ? "#{overdue_tasks} overdue" : "No overdue tasks",
          status: overdue_tasks.positive? ? "blocked" : "in_progress",
          accent: "bg-cyan-500"
        ),
        CommandMetricDto.new(
          label: "Documents in review",
          value: attention_documents,
          hint: attention_documents.positive? ? "Pending, expired, or expiring" : "Document queue clear",
          status: attention_documents.positive? ? "needs_review" : "ready",
          accent: "bg-amber-500"
        ),
        CommandMetricDto.new(
          label: "Payroll ready",
          value: readiness.count(&:payroll_ready),
          hint: "Compensation configured",
          status: readiness.all?(&:payroll_ready) ? "ready" : "needs_review",
          accent: "bg-indigo-500"
        )
      ]
    end

    def lanes(tasks)
      tasks
        .group_by(&:owner)
        .sort_by { |owner, _tasks| owner.to_s }
        .map { |owner, lane_tasks| LaneDto.from_tasks(owner, lane_tasks) }
    end
  end
end
