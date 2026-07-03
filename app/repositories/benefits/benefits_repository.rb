module Benefits
  class BenefitsRepository < ApplicationRepository
    def initialize(employer:)
      @employer = employer
    end

    def plans
      return BenefitPlan.none unless @employer

      @employer.benefit_plans.includes(:enrollments).order(:category, :name)
    end

    def enrollments
      Enrollment
        .joins(:employee)
        .where(employees: { employer_id: @employer&.id })
        .includes(:employee, :benefit_plan)
        .order(created_at: :desc)
    end

    def accepted_enrollment_count
      enrollments.accepted.count
    end

    def pending_enrollment_count
      enrollments.pending.count
    end

    def current_payroll_run
      return unless @employer

      @employer.payroll_runs.order(pay_date: :desc).first
    end

    def reconciliation_enrollments
      Enrollment
        .joins(:employee)
        .where(employees: { employer_id: @employer&.id })
        .includes(:benefit_plan, employee: [ :employer ], payroll_deductions: [ :payroll_run ])
        .order(created_at: :desc)
    end

    def find(id)
      Enrollment.find(id)
    end

    def find_reconciliation_enrollment(id)
      Enrollment
        .includes(:benefit_plan, employee: [ :employer ], payroll_deductions: [ :payroll_run ])
        .find(id)
    end

    def find_detail(id)
      Enrollment
        .includes(
          :benefit_plan,
          employee: [ :department, :work_location, employer: [ :organization ] ],
          payroll_deductions: [ :payroll_run, :employee, enrollment: [ :benefit_plan ] ],
        )
        .find(id)
    end

    def review_enrollment(enrollment, decision)
      Enrollment.transaction do
        enrollment.update!(
          status: decision,
          accepted_at: decision == "accepted" ? Time.current : nil,
          effective_on: enrollment.effective_on || Date.current.beginning_of_month.next_month
        )
        sync_payroll_deductions(enrollment, decision)
      end

      enrollment
    end

    def resolve_reconciliation_item(enrollment)
      employer = @employer || enrollment.employee.employer
      run = current_or_create_payroll_run(employer)
      deduction = enrollment.payroll_deductions.find { |item| item.payroll_run_id == run.id }

      attributes = {
        employee: enrollment.employee,
        enrollment:,
        code: reconciliation_code(enrollment),
        amount_cents: expected_amount_cents(enrollment),
        status: expected_deduction_status(enrollment)
      }

      if deduction
        deduction.update!(attributes)
        deduction
      else
        run.payroll_deductions.create!(attributes)
      end
    end

    private

    def sync_payroll_deductions(enrollment, decision)
      enrollment.payroll_deductions.find_each do |deduction|
        if decision == "accepted"
          deduction.update!(amount_cents: enrollment.benefit_plan.monthly_premium_cents, status: "ready")
        else
          deduction.update!(amount_cents: 0, status: "waived")
        end
      end
    end

    def current_or_create_payroll_run(employer)
      employer.payroll_runs.order(pay_date: :desc).first ||
        employer.payroll_runs.create!(
          period_start_on: Date.current.beginning_of_month,
          period_end_on: Date.current.end_of_month,
          pay_date: Date.current.end_of_month,
          gross_pay_cents: 0,
          status: "estimated"
        )
    end

    def reconciliation_code(enrollment)
      "VITABLE_#{enrollment.benefit_plan.category.upcase.gsub(/[^A-Z0-9]+/, "_")}"
    end

    def expected_amount_cents(enrollment)
      enrollment.status == "accepted" ? enrollment.benefit_plan.monthly_premium_cents : 0
    end

    def expected_deduction_status(enrollment)
      case enrollment.status
      when "accepted" then "ready"
      when "waived" then "waived"
      else "waiting_on_enrollment"
      end
    end
  end
end
