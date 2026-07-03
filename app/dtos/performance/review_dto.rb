module Performance
  ReviewDto = Data.define(:id, :cycle_id, :cycle_name, :employee_id, :employee_name, :employee_title, :department_name, :reviewer_id, :reviewer_name, :status, :rating, :due_on, :strengths, :growth_areas, :readiness_status, :readiness_reason) do
    def self.from_record(record)
      employee = record.employee

      new(
        id: record.id,
        cycle_id: record.performance_cycle_id,
        cycle_name: record.performance_cycle.name,
        employee_id: employee.id,
        employee_name: employee.full_name,
        employee_title: employee.title,
        department_name: employee.department&.name,
        reviewer_id: record.reviewer_id,
        reviewer_name: record.reviewer&.full_name || "Reviewer pending",
        status: record.overdue? ? "overdue" : record.status,
        rating: record.rating,
        due_on: record.due_on,
        strengths: record.strengths,
        growth_areas: record.growth_areas,
        readiness_status: readiness_status(record),
        readiness_reason: readiness_reason(record)
      )
    end

    def calibratable?
      status.in?(%w[manager_review calibration])
    end

    private_class_method def self.readiness_status(record)
      return "ready" if record.calibratable?
      return "complete" if record.complete?
      return "overdue" if record.overdue?

      "in_progress"
    end

    private_class_method def self.readiness_reason(record)
      return "Ready for calibration review" if record.calibratable?
      return "Review has been completed" if record.complete?
      return "Review is past due" if record.overdue?

      "Waiting for self or manager review"
    end
  end
end
