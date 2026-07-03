module Benefits
  EnrollmentDetailDto = Data.define(
    :id,
    :employee_id,
    :employee_name,
    :employee_title,
    :employee_status,
    :department_name,
    :work_location_name,
    :employer_name,
    :organization_name,
    :benefit_plan_id,
    :benefit_plan_name,
    :category,
    :carrier,
    :plan_status,
    :monthly_premium_cents,
    :coverage_level,
    :effective_on,
    :accepted_at,
    :status,
    :vitable_id,
    :payroll_deduction_count,
    :payroll_deduction_cents,
    :payroll_deductions,
    :preflight_checks,
    :timeline,
    :export_payload
  ) do
    def self.from_record(record)
      deductions = record.payroll_deductions.to_a

      new(
        id: record.id,
        employee_id: record.employee_id,
        employee_name: record.employee.full_name,
        employee_title: record.employee.title,
        employee_status: record.employee.employment_status,
        department_name: record.employee.department&.name,
        work_location_name: record.employee.work_location&.name,
        employer_name: record.employee.employer.name,
        organization_name: record.employee.employer.organization.name,
        benefit_plan_id: record.benefit_plan_id,
        benefit_plan_name: record.benefit_plan.name,
        category: record.benefit_plan.category,
        carrier: record.benefit_plan.carrier,
        plan_status: record.benefit_plan.status,
        monthly_premium_cents: record.benefit_plan.monthly_premium_cents,
        coverage_level: record.coverage_level,
        effective_on: record.effective_on,
        accepted_at: record.accepted_at,
        status: record.status,
        vitable_id: record.vitable_id,
        payroll_deduction_count: deductions.count,
        payroll_deduction_cents: deductions.sum(&:amount_cents),
        payroll_deductions: deductions.sort_by(&:created_at).reverse.map { |deduction| Operations::PayrollDeductionDto.from_record(deduction) },
        preflight_checks: preflight_checks(record, deductions),
        timeline: timeline(record, deductions),
        export_payload: export_payload(record, deductions)
      )
    end

    def accepted?
      status == "accepted"
    end

    def waived?
      status == "waived"
    end

    def actionable?
      !accepted? && !waived?
    end

    def annual_premium_cents
      monthly_premium_cents * 12
    end

    def self.preflight_checks(record, deductions)
      [
        EnrollmentPreflightCheckDto.new(
          label: "Employee eligibility",
          status: record.employee.employment_status == "active" ? "ready" : "needs_review",
          detail: "#{record.employee.full_name} is #{record.employee.employment_status.humanize.downcase}"
        ),
        EnrollmentPreflightCheckDto.new(
          label: "Plan availability",
          status: record.benefit_plan.status == "available" ? "ready" : "needs_review",
          detail: "#{record.benefit_plan.name} is #{record.benefit_plan.status.humanize.downcase}"
        ),
        EnrollmentPreflightCheckDto.new(
          label: "Payroll deduction",
          status: deductions.any? ? deduction_status(deductions) : "needs_review",
          detail: deductions.any? ? "#{deductions.count} payroll deductions linked" : "No payroll deduction linked yet"
        ),
        EnrollmentPreflightCheckDto.new(
          label: "Vitable mapping",
          status: record.vitable_id.present? ? "ready" : "needs_credentials",
          detail: record.vitable_id.presence || "Waiting for remote enrollment ID"
        )
      ]
    end

    def self.timeline(record, deductions)
      [
        EnrollmentTimelineItemDto.new(
          type: "Enrollment",
          title: record.benefit_plan.name,
          subtitle: record.coverage_level.humanize,
          status: record.status,
          timestamp: record.accepted_at || record.updated_at
        ),
        *deductions.map do |deduction|
          EnrollmentTimelineItemDto.new(
            type: "Payroll",
            title: deduction.code,
            subtitle: "Pay date #{deduction.payroll_run.pay_date.strftime('%b %-d, %Y')}",
            status: deduction.status,
            timestamp: deduction.updated_at
          )
        end
      ].sort_by(&:timestamp).reverse
    end

    def self.export_payload(record, deductions)
      {
        enrollment_id: record.id,
        vitable_id: record.vitable_id,
        employee_id: record.employee_id,
        benefit_plan_id: record.benefit_plan_id,
        status: record.status,
        coverage_level: record.coverage_level,
        effective_on: record.effective_on&.iso8601,
        payroll_deductions: deductions.map do |deduction|
          {
            payroll_run_id: deduction.payroll_run_id,
            code: deduction.code,
            amount_cents: deduction.amount_cents,
            status: deduction.status
          }
        end
      }
    end

    def self.deduction_status(deductions)
      return "waived" if deductions.all? { |deduction| deduction.status == "waived" }
      return "ready" if deductions.all? { |deduction| deduction.status == "ready" }

      "needs_review"
    end

    private_class_method :preflight_checks, :timeline, :export_payload, :deduction_status
  end
end
