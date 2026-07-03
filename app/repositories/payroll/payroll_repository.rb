module Payroll
  class PayrollRepository < ApplicationRepository
    def initialize(employer: nil)
      @employer = employer
    end

    def runs
      return PayrollRun.none unless @employer

      @employer.payroll_runs.includes(:payroll_deductions, :payroll_adjustments).order(pay_date: :desc)
    end

    def current_run
      runs.first
    end

    def adjustments
      PayrollAdjustment
        .joins(:payroll_run)
        .where(payroll_runs: { employer_id: @employer&.id })
        .includes(:employee)
        .order(created_at: :desc)
    end

    def deductions
      PayrollDeduction
        .joins(:payroll_run)
        .where(payroll_runs: { employer_id: @employer&.id })
        .includes(:employee, enrollment: [ :benefit_plan ])
        .order(created_at: :desc)
    end

    def find_run(id)
      PayrollRun.find(id)
    end

    def find_detail(id)
      PayrollRun
        .includes(
          employer: [ :organization ],
          payroll_deductions: [ :payroll_run, :employee, { enrollment: [ :benefit_plan ] } ],
          payroll_adjustments: [ :payroll_run, :employee ]
        )
        .find(id)
    end

    def find_export_detail(id)
      PayrollRun
        .includes(
          employer: [ :organization ],
          payroll_deductions: [ :employee, { enrollment: [ :benefit_plan ] } ]
        )
        .find(id)
    end

    def finalize(run)
      run.update!(status: "finalized")
      run
    end

    def generate_benefits_export(run)
      lines = benefits_export_lines(run)
      batch = {
        batch_id: "vitable_benefits_#{run.id}_#{Time.current.to_i}",
        generated_at: Time.current.iso8601,
        payroll_run_id: run.id,
        employer_id: run.employer_id,
        status: run.status == "finalized" ? "ready" : "needs_review",
        line_count: lines.count,
        holdback_count: run.payroll_deductions.count - lines.count,
        total_cents: lines.sum { |line| line.fetch(:amount_cents) },
        lines:
      }

      run.update!(metadata: run.metadata.to_h.merge(benefits_export: batch))
      batch
    end

    private

    def benefits_export_lines(run)
      run.payroll_deductions.select { |deduction| deduction.status == "ready" && deduction.amount_cents.positive? }.map do |deduction|
        {
          deduction_id: deduction.id,
          employee_id: deduction.employee_id,
          employee_name: deduction.employee.full_name,
          code: deduction.code,
          amount_cents: deduction.amount_cents,
          plan_name: deduction.enrollment&.benefit_plan&.name,
          enrollment_id: deduction.enrollment_id,
          coverage_level: deduction.enrollment&.coverage_level,
          vitable_id: deduction.vitable_id
        }
      end
    end
  end
end
