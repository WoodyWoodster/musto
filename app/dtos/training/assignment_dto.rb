module Training
  AssignmentDto = Data.define(:id, :program_id, :program_title, :employee_id, :employee_name, :employee_title, :department_name, :location_name, :status, :due_on, :completed_at, :score, :certificate_id, :readiness_status, :readiness_reason) do
    def self.from_record(record)
      employee = record.employee

      new(
        id: record.id,
        program_id: record.training_program_id,
        program_title: record.training_program.title,
        employee_id: employee.id,
        employee_name: employee.full_name,
        employee_title: employee.title,
        department_name: employee.department&.name,
        location_name: employee.work_location&.name,
        status: record.overdue? ? "overdue" : record.status,
        due_on: record.due_on,
        completed_at: record.completed_at,
        score: record.score,
        certificate_id: record.certificate_id,
        readiness_status: readiness_status(record),
        readiness_reason: readiness_reason(record)
      )
    end

    def completable?
      status.in?(%w[assigned in_progress overdue])
    end

    private_class_method def self.readiness_status(record)
      return "certificate_ready" if record.complete? && record.certificate_id.present?
      return "complete" if record.complete?
      return "overdue" if record.overdue?

      "in_progress"
    end

    private_class_method def self.readiness_reason(record)
      return "Certificate is ready for audit export" if record.complete? && record.certificate_id.present?
      return "Completed but missing certificate reference" if record.complete?
      return "Training assignment is past due" if record.overdue?

      "Employee still needs to complete training"
    end
  end
end
