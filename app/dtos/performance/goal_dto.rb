module Performance
  GoalDto = Data.define(:id, :employee_id, :employee_name, :department_name, :cycle_name, :title, :description, :status, :progress_percent, :due_on, :owner, :metric, :readiness_status, :readiness_reason) do
    def self.from_record(record)
      new(
        id: record.id,
        employee_id: record.employee_id,
        employee_name: record.employee.full_name,
        department_name: record.employee.department&.name,
        cycle_name: record.performance_cycle&.name,
        title: record.title,
        description: record.description,
        status: record.status,
        progress_percent: record.progress_percent,
        due_on: record.due_on,
        owner: record.owner,
        metric: record.metric,
        readiness_status: readiness_status(record),
        readiness_reason: readiness_reason(record)
      )
    end

    def completable?
      status != "complete"
    end

    private_class_method def self.readiness_status(record)
      return "complete" if record.complete?
      return "blocked" if record.at_risk?
      return "due_soon" if record.due_on <= 14.days.from_now.to_date

      "on_track"
    end

    private_class_method def self.readiness_reason(record)
      return "Goal is complete" if record.complete?
      return "Goal is at risk and needs manager attention" if record.at_risk?
      return "Goal is due within the next two weeks" if record.due_on <= 14.days.from_now.to_date

      "Goal is tracking to plan"
    end
  end
end
