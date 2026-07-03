module Benefits
  DependentVerificationRecordDto = Data.define(:id, :dependent_id, :dependent_name, :employee_id, :employee_name, :verification_type, :status, :requested_on, :due_on, :reviewed_at, :reviewed_by, :issue_code, :note, :document_id, :document_title, :document_status) do
    def self.from_record(record)
      document = record.employee_document

      new(
        id: record.id,
        dependent_id: record.dependent_id,
        dependent_name: record.dependent.full_name,
        employee_id: record.dependent.employee_id,
        employee_name: record.dependent.employee.full_name,
        verification_type: record.verification_type,
        status: record.status,
        requested_on: record.requested_on,
        due_on: record.due_on,
        reviewed_at: record.reviewed_at,
        reviewed_by: record.reviewed_by,
        issue_code: record.issue_code,
        note: record.note,
        document_id: document&.id,
        document_title: document&.title,
        document_status: document&.status || "missing"
      )
    end

    def reviewable?
      status.in?([ "requested", "needs_review" ]) && document_status == "complete"
    end
  end
end
