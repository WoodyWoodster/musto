module Benefits
  OffboardingEventDto = Data.define(
    :id,
    :employee_id,
    :employee_name,
    :event_type,
    :status,
    :effective_on,
    :summary,
    :remote_employee_id,
    :enrollment_count,
    :covered_dependent_count,
    :benefits_impact,
    :compliance_impact,
    :readiness_status,
    :readiness_reason
  ) do
    def self.from_record(record)
      metadata = record.metadata.to_h.stringify_keys
      accepted_enrollments = record.employee.enrollments.select { |enrollment| enrollment.status == "accepted" }
      covered_dependents = record.employee.dependents.select(&:eligible?)
      readiness = readiness_for(record, accepted_enrollments)

      new(
        id: record.id,
        employee_id: record.employee_id,
        employee_name: record.employee.full_name,
        event_type: record.event_type,
        status: record.status,
        effective_on: record.effective_on,
        summary: record.summary,
        remote_employee_id: record.employee.vitable_id,
        enrollment_count: accepted_enrollments.count,
        covered_dependent_count: covered_dependents.count,
        benefits_impact: metadata.fetch("benefits_impact", "none"),
        compliance_impact: metadata.fetch("compliance_impact", "none"),
        readiness_status: readiness.fetch(:status),
        readiness_reason: readiness.fetch(:reason)
      )
    end

    def ready?
      readiness_status == "ready"
    end

    private_class_method def self.readiness_for(record, accepted_enrollments)
      return { status: "needs_review", reason: "Lifecycle event must be approved before coverage termination." } unless record.approved? || record.sync_queued?
      return { status: "needs_review", reason: "No accepted benefit coverage found for this employee." } if accepted_enrollments.empty?
      return { status: "remote_pending", reason: "Remote employee ID is required before sending coverage termination." } if record.employee.vitable_id.blank?

      { status: "ready", reason: "Coverage termination can be included in the next Vitable packet." }
    end
  end
end
