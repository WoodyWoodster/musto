module Employees
  ProfileDto = Data.define(
    :id,
    :full_name,
    :email,
    :title,
    :employer_id,
    :employer_name,
    :organization_name,
    :department_name,
    :work_location_name,
    :employment_status,
    :onboarding_status,
    :pay_type,
    :compensation_cents,
    :start_on,
    :vitable_id,
    :benefits_status,
    :accepted_enrollment_count,
    :pending_enrollment_count,
    :open_onboarding_count,
    :document_attention_count,
    :pending_time_off_count,
    :open_compliance_case_count,
    :payroll_deduction_cents,
    :metrics,
    :enrollments,
    :payroll_deductions,
    :payroll_adjustments,
    :onboarding_tasks,
    :documents,
    :time_off_requests,
    :compliance_cases,
    :timeline
  ) do
    def self.from_record(record)
      accepted_enrollment_count = record.enrollments.count { |enrollment| enrollment.status == "accepted" }
      pending_enrollment_count = record.enrollments.count { |enrollment| enrollment.status == "pending" }
      open_onboarding_count = record.onboarding_tasks.count { |task| task.status != "complete" }
      document_attention_count = record.employee_documents.count { |document| %w[pending expired].include?(document.status) }
      pending_time_off_count = record.time_off_requests.count { |request| request.status == "requested" }
      open_compliance_case_count = record.compliance_cases.count { |compliance_case| compliance_case.status != "resolved" }
      payroll_deduction_cents = record.payroll_deductions.sum(&:amount_cents)

      new(
        id: record.id,
        full_name: record.full_name,
        email: record.email,
        title: record.title,
        employer_id: record.employer_id,
        employer_name: record.employer.name,
        organization_name: record.employer.organization.name,
        department_name: record.department&.name,
        work_location_name: record.work_location&.name,
        employment_status: record.employment_status,
        onboarding_status: record.onboarding_status,
        pay_type: record.pay_type,
        compensation_cents: record.compensation_cents,
        start_on: record.start_on,
        vitable_id: record.vitable_id,
        benefits_status: accepted_enrollment_count.positive? ? "accepted" : "pending",
        accepted_enrollment_count:,
        pending_enrollment_count:,
        open_onboarding_count:,
        document_attention_count:,
        pending_time_off_count:,
        open_compliance_case_count:,
        payroll_deduction_cents:,
        metrics: metrics(record, accepted_enrollment_count, open_onboarding_count, document_attention_count, open_compliance_case_count),
        enrollments: record.enrollments.sort_by(&:created_at).reverse.map { |enrollment| Operations::EnrollmentDto.from_record(enrollment) },
        payroll_deductions: record.payroll_deductions.sort_by(&:created_at).reverse.map { |deduction| Operations::PayrollDeductionDto.from_record(deduction) },
        payroll_adjustments: record.payroll_adjustments.sort_by(&:created_at).reverse.map { |adjustment| Operations::PayrollAdjustmentDto.from_record(adjustment) },
        onboarding_tasks: record.onboarding_tasks.sort_by(&:due_on).map { |task| Operations::OnboardingTaskDto.from_record(task) },
        documents: record.employee_documents.sort_by { |document| document.expires_on || Date.current + 100.years }.map { |document| Operations::DocumentExceptionDto.from_record(document) },
        time_off_requests: record.time_off_requests.sort_by(&:starts_on).map { |request| Operations::TimeOffRequestDto.from_record(request) },
        compliance_cases: record.compliance_cases.sort_by { |item| [ severity_rank(item.severity), item.due_on || Date.current + 100.years ] }.map { |item| Operations::ComplianceCaseDto.from_record(item) },
        timeline: timeline(record)
      )
    end

    def connected_to_vitable?
      vitable_id.present?
    end

    def active?
      employment_status == "active"
    end

    def needs_attention?
      open_onboarding_count.positive? ||
        document_attention_count.positive? ||
        pending_time_off_count.positive? ||
        open_compliance_case_count.positive?
    end

    def self.metrics(record, accepted_enrollment_count, open_onboarding_count, document_attention_count, open_compliance_case_count)
      [
        ProfileMetricDto.new(label: "Compensation", value: record.compensation_cents, hint: record.pay_type.humanize, accent: "bg-indigo-500"),
        ProfileMetricDto.new(label: "Benefits accepted", value: accepted_enrollment_count, hint: "active elections", accent: "bg-emerald-500"),
        ProfileMetricDto.new(label: "Open onboarding", value: open_onboarding_count, hint: "tasks remaining", accent: "bg-cyan-500"),
        ProfileMetricDto.new(label: "Risk items", value: document_attention_count + open_compliance_case_count, hint: "docs and cases", accent: "bg-rose-500")
      ]
    end

    def self.timeline(record)
      [
        *record.onboarding_tasks.map do |task|
          ProfileTimelineItemDto.new(
            type: "Onboarding",
            title: task.title,
            subtitle: "#{task.owner.humanize} owner · due #{task.due_on.strftime('%b %-d')}",
            status: task.status,
            timestamp: task.completed_at || task.updated_at
          )
        end,
        *record.enrollments.map do |enrollment|
          ProfileTimelineItemDto.new(
            type: "Benefits",
            title: enrollment.benefit_plan.name,
            subtitle: enrollment.coverage_level.humanize,
            status: enrollment.status,
            timestamp: enrollment.accepted_at || enrollment.updated_at
          )
        end,
        *record.payroll_deductions.map do |deduction|
          ProfileTimelineItemDto.new(
            type: "Payroll",
            title: deduction.code,
            subtitle: deduction.enrollment&.benefit_plan&.name || "Pending enrollment",
            status: deduction.status,
            timestamp: deduction.updated_at
          )
        end,
        *record.compliance_cases.map do |item|
          ProfileTimelineItemDto.new(
            type: "Compliance",
            title: item.kind.humanize,
            subtitle: item.description.presence || "Compliance case",
            status: item.status,
            timestamp: item.resolved_at || item.updated_at
          )
        end
      ].sort_by(&:timestamp).reverse.first(10)
    end

    def self.severity_rank(severity)
      { "critical" => 0, "high" => 1, "medium" => 2 }.fetch(severity, 3)
    end

    private_class_method :metrics, :timeline, :severity_rank
  end
end
