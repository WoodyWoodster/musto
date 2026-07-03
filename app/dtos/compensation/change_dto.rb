module Compensation
  ChangeDto = Data.define(
    :id,
    :employee_id,
    :employee_name,
    :employee_title,
    :department_name,
    :location_name,
    :payroll_run_id,
    :pay_date,
    :change_type,
    :status,
    :reason,
    :current_compensation_cents,
    :proposed_compensation_cents,
    :delta_cents,
    :effective_on,
    :submitted_by,
    :submitted_at,
    :approved_by,
    :approved_at,
    :rejection_reason,
    :applied_at,
    :readiness_status,
    :readiness_reason
  ) do
    def self.from_record(record)
      employee = record.employee

      new(
        id: record.id,
        employee_id: employee.id,
        employee_name: employee.full_name,
        employee_title: employee.title,
        department_name: employee.department&.name || "Unassigned",
        location_name: employee.work_location&.name || "Missing location",
        payroll_run_id: record.payroll_run_id,
        pay_date: record.payroll_run&.pay_date,
        change_type: record.change_type,
        status: record.status,
        reason: record.reason,
        current_compensation_cents: record.current_compensation_cents,
        proposed_compensation_cents: record.proposed_compensation_cents,
        delta_cents: record.delta_cents,
        effective_on: record.effective_on,
        submitted_by: record.submitted_by,
        submitted_at: record.submitted_at,
        approved_by: record.approved_by,
        approved_at: record.approved_at,
        rejection_reason: record.rejection_reason,
        applied_at: record.applied_at,
        readiness_status: readiness_status(record),
        readiness_reason: readiness_reason(record)
      )
    end

    def reviewable?
      status.in?(%w[draft submitted])
    end

    def approved?
      status == "approved"
    end

    def applied?
      status == "applied"
    end

    private_class_method def self.readiness_status(record)
      return "ready" if record.approved?
      return "succeeded" if record.applied?
      return "rejected" if record.rejected?

      "needs_review"
    end

    private_class_method def self.readiness_reason(record)
      return "Approved and ready for compensation packet" if record.approved?
      return "Applied to employee pay or payroll adjustment" if record.applied?
      return record.rejection_reason.presence || "Rejected by reviewer" if record.rejected?

      "Needs People and Finance approval"
    end
  end
end
