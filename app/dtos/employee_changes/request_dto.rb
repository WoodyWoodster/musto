module EmployeeChanges
  RequestDto = Data.define(
    :id,
    :employee_id,
    :employee_name,
    :employee_email,
    :employee_title,
    :department_name,
    :location_name,
    :remote_employee_id,
    :request_type,
    :title,
    :summary,
    :status,
    :effective_on,
    :submitted_at,
    :reviewed_at,
    :reviewed_by,
    :payroll_impact,
    :benefits_impact,
    :compliance_impact,
    :payload_preview,
    :readiness_status,
    :readiness_reason
  ) do
    def self.from_record(record)
      employee = record.employee

      new(
        id: record.id,
        employee_id: employee.id,
        employee_name: employee.full_name,
        employee_email: employee.email,
        employee_title: employee.title,
        department_name: employee.department&.name,
        location_name: employee.work_location&.name,
        remote_employee_id: employee.vitable_id,
        request_type: record.request_type,
        title: record.title,
        summary: record.summary,
        status: record.status,
        effective_on: record.effective_on,
        submitted_at: record.submitted_at,
        reviewed_at: record.reviewed_at,
        reviewed_by: record.reviewed_by,
        payroll_impact: record.payroll_impact,
        benefits_impact: record.benefits_impact,
        compliance_impact: record.compliance_impact,
        payload_preview: payload_preview(record),
        readiness_status: readiness_status(record),
        readiness_reason: readiness_reason(record)
      )
    end

    def reviewable?
      status == "submitted"
    end

    def applied?
      status == "applied"
    end

    private_class_method def self.payload_preview(record)
      payload = record.payload
      return "No payload attached" if payload.empty?

      payload.map { |key, value| "#{key.to_s.humanize}: #{value}" }.first(3).join(" · ")
    end

    private_class_method def self.readiness_status(record)
      return "needs_review" if record.submitted?
      return "ready" if record.applied?
      return "sync_queued" if record.sync_queued?
      return "rejected" if record.rejected?

      "pending"
    end

    private_class_method def self.readiness_reason(record)
      return "Needs People Ops approval before local records change" if record.submitted?
      return "Applied locally and ready for Vitable sync packaging" if record.applied?
      return "Queued in latest employee change sync batch" if record.sync_queued?
      return "Rejected by reviewer" if record.rejected?

      "Waiting for review"
    end
  end
end
