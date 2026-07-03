module Onboarding
  EmployeeReadinessDto = Data.define(
    :id,
    :full_name,
    :title,
    :department_name,
    :work_location_name,
    :onboarding_status,
    :open_task_count,
    :overdue_task_count,
    :pending_document_count,
    :accepted_enrollment_count,
    :payroll_ready,
    :readiness_percent,
    :status
  ) do
    def self.from_record(record)
      open_tasks = record.onboarding_tasks.reject { |task| task.status == "complete" }
      pending_documents = record.employee_documents.select { |document| document.status != "complete" || document.expired? }
      accepted_enrollment_count = record.enrollments.count { |enrollment| enrollment.status == "accepted" }
      payroll_ready = record.compensation_cents.positive?

      new(
        id: record.id,
        full_name: record.full_name,
        title: record.title,
        department_name: record.department&.name,
        work_location_name: record.work_location&.name,
        onboarding_status: record.onboarding_status,
        open_task_count: open_tasks.count,
        overdue_task_count: open_tasks.count(&:overdue?),
        pending_document_count: pending_documents.count,
        accepted_enrollment_count:,
        payroll_ready:,
        readiness_percent: readiness_percent(open_tasks, pending_documents, accepted_enrollment_count, payroll_ready),
        status: readiness_status(open_tasks, pending_documents, accepted_enrollment_count, payroll_ready)
      )
    end

    def ready?
      status == "ready"
    end

    def blocked?
      status == "blocked"
    end

    def needs_attention?
      blocked? || status == "needs_review"
    end

    def self.readiness_percent(open_tasks, pending_documents, accepted_enrollment_count, payroll_ready)
      [
        20,
        (payroll_ready ? 20 : 0),
        (accepted_enrollment_count.positive? ? 20 : 0),
        (open_tasks.empty? ? 20 : 0),
        (pending_documents.empty? ? 20 : 0)
      ].sum
    end

    def self.readiness_status(open_tasks, pending_documents, accepted_enrollment_count, payroll_ready)
      return "blocked" if open_tasks.any?(&:overdue?) || pending_documents.any?
      return "ready" if open_tasks.empty? && accepted_enrollment_count.positive? && payroll_ready

      "needs_review"
    end

    private_class_method :readiness_percent, :readiness_status
  end
end
