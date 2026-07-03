module Training
  AuditHoldbackDto = Data.define(:assignment_id, :employee_name, :program_title, :status, :reason) do
    def self.from_hash(payload)
      new(
        assignment_id: payload.fetch("assignment_id", nil),
        employee_name: payload.fetch("employee_name", "Training program"),
        program_title: payload.fetch("program_title", "Training program"),
        status: payload.fetch("status", "needs_review"),
        reason: payload.fetch("reason", "Needs review")
      )
    end
  end
end
