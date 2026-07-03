module Benefits
  EligibilityMemberDto = Data.define(
    :employee_id,
    :employee_name,
    :department_name,
    :location_name,
    :enrollment_id,
    :plan_name,
    :plan_category,
    :coverage_level,
    :effective_on,
    :enrollment_status,
    :remote_employee_id,
    :remote_enrollment_id,
    :dependent_count,
    :eligible_dependent_count,
    :readiness_status,
    :readiness_reason
  ) do
    def self.from_enrollment(enrollment)
      employee = enrollment.employee
      dependents = employee.dependents
      ready = enrollment.status == "accepted" && enrollment.effective_on.present?

      new(
        employee_id: employee.id,
        employee_name: employee.full_name,
        department_name: employee.department&.name || "Unassigned",
        location_name: employee.work_location&.name || "No location",
        enrollment_id: enrollment.id,
        plan_name: enrollment.benefit_plan.name,
        plan_category: enrollment.benefit_plan.category,
        coverage_level: enrollment.coverage_level,
        effective_on: enrollment.effective_on,
        enrollment_status: enrollment.status,
        remote_employee_id: employee.vitable_id,
        remote_enrollment_id: enrollment.vitable_id,
        dependent_count: dependents.count,
        eligible_dependent_count: dependents.select(&:eligible?).count,
        readiness_status: ready ? "ready" : "needs_review",
        readiness_reason: readiness_reason(enrollment)
      )
    end

    def ready?
      readiness_status == "ready"
    end

    def remote_pending?
      remote_employee_id.blank? || remote_enrollment_id.blank?
    end

    def self.readiness_reason(enrollment)
      return "Enrollment is not accepted" unless enrollment.status == "accepted"
      return "Effective date is missing" if enrollment.effective_on.blank?

      "Ready for eligibility sync"
    end
  end
end
