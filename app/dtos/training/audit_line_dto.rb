module Training
  AuditLineDto = Data.define(:assignment_id, :employee_id, :employee_name, :program_title, :category, :completed_at, :score, :certificate_id, :status) do
    def self.from_hash(payload)
      new(
        assignment_id: payload.fetch("assignment_id", nil),
        employee_id: payload.fetch("employee_id", nil),
        employee_name: payload.fetch("employee_name", "Employee pending"),
        program_title: payload.fetch("program_title", "Training program"),
        category: payload.fetch("category", "compliance"),
        completed_at: payload.fetch("completed_at", nil),
        score: payload.fetch("score", nil),
        certificate_id: payload.fetch("certificate_id", nil),
        status: payload.fetch("status", "ready")
      )
    end
  end
end
