module OpenEnrollment
  InvitationDto = Data.define(
    :id,
    :employee_id,
    :employee_name,
    :department_name,
    :location_name,
    :status,
    :due_on,
    :sent_at,
    :opened_at,
    :completed_at,
    :last_reminded_at,
    :accepted_enrollment_count,
    :pending_enrollment_count,
    :waived_enrollment_count,
    :dependent_review_count,
    :remote_pending_count,
    :readiness_status,
    :readiness_reason
  ) do
    def self.from_record(record, enrollments:, dependents:)
      accepted = enrollments.count { |enrollment| enrollment.status == "accepted" }
      pending = enrollments.count { |enrollment| enrollment.status == "pending" }
      waived = enrollments.count { |enrollment| enrollment.status == "waived" }
      dependent_review_count = dependents.count { |dependent| !dependent.eligible? }
      remote_pending_count = enrollments.count { |enrollment| enrollment.status == "accepted" && enrollment.vitable_id.blank? }

      new(
        id: record.id,
        employee_id: record.employee_id,
        employee_name: record.employee.full_name,
        department_name: record.employee.department&.name,
        location_name: record.employee.work_location&.name,
        status: record.status,
        due_on: record.due_on,
        sent_at: record.sent_at,
        opened_at: record.opened_at,
        completed_at: record.completed_at,
        last_reminded_at: record.last_reminded_at,
        accepted_enrollment_count: accepted,
        pending_enrollment_count: pending,
        waived_enrollment_count: waived,
        dependent_review_count:,
        remote_pending_count:,
        readiness_status: readiness_status(record, pending, dependent_review_count),
        readiness_reason: readiness_reason(record, pending, dependent_review_count, remote_pending_count)
      )
    end

    def complete?
      status == "completed"
    end

    def remindable?
      status.in?([ "sent", "opened", "reminded", "blocked" ])
    end

    def self.readiness_status(record, pending, dependent_review_count)
      return "blocked" if dependent_review_count.positive?
      return "needs_review" if pending.positive?
      return "ready" if record.status.in?([ "completed", "waived" ])

      "in_progress"
    end

    def self.readiness_reason(record, pending, dependent_review_count, remote_pending_count)
      return "#{dependent_review_count} dependents need eligibility review" if dependent_review_count.positive?
      return "#{pending} elections are still pending" if pending.positive?
      return "#{remote_pending_count} accepted elections need Vitable IDs" if remote_pending_count.positive?
      return "Employee completed open enrollment" if record.status == "completed"
      return "Employee waived open enrollment" if record.status == "waived"

      "Waiting for employee action"
    end

    private_class_method :readiness_status, :readiness_reason
  end
end
