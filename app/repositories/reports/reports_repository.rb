module Reports
  class ReportsRepository < ApplicationRepository
    def initialize(employer: nil)
      @employer = employer
    end

    def employees
      return Employee.none unless @employer

      @employer.employees.includes(:department, :employee_documents, enrollments: [ :benefit_plan ], payroll_deductions: [ :payroll_run ])
    end

    def departments
      return Department.none unless @employer

      @employer.departments.includes(:employees).order(:name)
    end

    def benefit_plans
      return BenefitPlan.none unless @employer

      @employer.benefit_plans.includes(:enrollments).order(:category, :name)
    end

    def payroll_runs
      return PayrollRun.none unless @employer

      @employer.payroll_runs.includes(:payroll_deductions, :payroll_adjustments).order(pay_date: :desc)
    end

    def payroll_deductions
      PayrollDeduction
        .joins(:payroll_run)
        .where(payroll_runs: { employer_id: @employer&.id })
        .includes(:employee, enrollment: [ :benefit_plan ])
    end

    def compliance_cases
      return ComplianceCase.none unless @employer

      @employer.compliance_cases.includes(:employee).order(severity_sort, :due_on)
    end

    def time_off_requests
      return TimeOffRequest.none unless @employer

      @employer.time_off_requests.includes(:employee, :time_off_policy).order(:starts_on)
    end

    def snapshots
      payload = @employer&.settings.to_h.fetch("report_snapshot", nil)
      payload.present? ? [ payload ] : []
    end

    def generate_snapshot(requested_by:)
      snapshot = {
        snapshot_id: "ops_reports_#{@employer.id}_#{Time.current.to_i}",
        generated_at: Time.current.iso8601,
        requested_by:,
        employer_id: @employer.id,
        status: snapshot_status,
        metrics: snapshot_metrics,
        exports: snapshot_exports
      }

      @employer.update!(settings: @employer.settings.to_h.merge("report_snapshot" => snapshot))
      snapshot
    end

    private

    def snapshot_status
      compliance_cases.any? { |item| item.status != "resolved" && %w[critical high].include?(item.severity) } ? "needs_review" : "ready"
    end

    def snapshot_metrics
      {
        active_employee_count: employees.count { |employee| employee.employment_status == "active" },
        payroll_ready_count: employees.count { |employee| employee.compensation_cents.positive? },
        gross_payroll_cents: payroll_runs.sum(&:gross_pay_cents),
        monthly_benefits_cost_cents: benefit_plans.sum { |plan| plan.enrollments.count { |enrollment| enrollment.status == "accepted" } * plan.monthly_premium_cents },
        ready_deduction_cents: payroll_deductions.select { |deduction| deduction.status == "ready" }.sum(&:amount_cents),
        open_compliance_count: compliance_cases.count { |item| item.status != "resolved" },
        pending_time_off_count: time_off_requests.count { |request| request.status == "requested" }
      }
    end

    def snapshot_exports
      [
        { key: "payroll_register", label: "Payroll register", row_count: payroll_runs.sum { |run| run.payroll_deductions.size + run.payroll_adjustments.size } },
        { key: "benefits_cost", label: "Benefits cost summary", row_count: benefit_plans.count },
        { key: "headcount", label: "Headcount by department", row_count: departments.count },
        { key: "compliance_risk", label: "Compliance risk queue", row_count: compliance_cases.count }
      ]
    end
  end
end
