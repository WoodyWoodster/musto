module Compensation
  class CompensationRepository < ApplicationRepository
    def initialize(employer: nil)
      @employer = employer
    end

    def employees
      return Employee.none unless @employer

      @employer
        .employees
        .active
        .includes(:department, :work_location, enrollments: [ :benefit_plan ], payroll_adjustments: [ :payroll_run ])
        .order(:last_name, :first_name)
    end

    def departments
      return Department.none unless @employer

      @employer.departments.includes(:employees).order(:name)
    end

    def payroll_adjustments
      PayrollAdjustment
        .joins(:payroll_run)
        .where(payroll_runs: { employer_id: @employer&.id })
        .includes(:employee, :payroll_run)
        .order(created_at: :desc)
    end

    def payroll_runs
      return PayrollRun.none unless @employer

      @employer.payroll_runs.includes(:payroll_adjustments, :payroll_deductions).order(pay_date: :desc)
    end

    def packets
      payload = @employer&.settings.to_h.fetch("compensation_packet", nil)
      payload.present? ? [ payload ] : []
    end

    def generate_packet(requested_by:)
      employees = self.employees.to_a
      departments = self.departments.to_a
      adjustments = payroll_adjustments.to_a
      recommendations = packet_recommendations(employees, departments, adjustments)
      packet = {
        "packet_id" => "comp_review_#{@employer.id}_#{Time.current.to_i}",
        "generated_at" => Time.current.iso8601,
        "requested_by" => requested_by,
        "employer_id" => @employer.id,
        "status" => recommendations.any? { |recommendation| recommendation.fetch("status") == "blocked" } ? "needs_review" : recommendations.any? ? "needs_review" : "ready",
        "totals" => {
          "employee_count" => employees.count,
          "annual_compensation_cents" => employees.sum(&:compensation_cents),
          "adjustment_cents" => adjustments.sum(&:amount_cents),
          "department_budget_cents" => departments.sum(&:budget_cents)
        },
        "recommendations" => recommendations
      }

      @employer.update!(settings: @employer.settings.to_h.merge("compensation_packet" => packet))
      packet
    end

    private

    def packet_recommendations(employees, departments, adjustments)
      recommendations = []
      blocked_employees = employees.select { |employee| employee.compensation_cents <= 0 || employee.department.blank? || employee.work_location.blank? }
      pending_enrollments = employees.sum { |employee| employee.enrollments.count { |enrollment| enrollment.status == "pending" } }

      recommendations << packet_recommendation("employee_setup", "Complete employee pay setup", "#{blocked_employees.count} employees are missing compensation, department, or work location data.", "high", "blocked") if blocked_employees.any?
      recommendations << packet_recommendation("benefit_alignment", "Resolve pending benefit elections", "#{pending_enrollments} Vitable benefit elections still affect payroll deductions.", "medium", "needs_review") if pending_enrollments.positive?
      recommendations << packet_recommendation("adjustment_review", "Review payroll adjustments", "#{adjustments.count} one-time compensation adjustments should be reviewed before packet release.", "medium", "needs_review") if adjustments.any?

      departments.each do |department|
        employees_in_department = employees.select { |employee| employee.department_id == department.id }
        planned_spend_cents = employees_in_department.sum(&:compensation_cents) + adjustments.select { |adjustment| adjustment.employee.department_id == department.id }.sum(&:amount_cents)
        utilization = department.budget_cents.positive? ? (planned_spend_cents.to_f / department.budget_cents * 100).round : 0
        next unless utilization >= 90 || planned_spend_cents > department.budget_cents

        recommendations << packet_recommendation("department_budget_#{department.id}", "Review #{department.name} budget exposure", "#{department.name} is at #{utilization}% of budget before annualized benefit load.", utilization > 100 ? "high" : "medium", utilization > 100 ? "blocked" : "needs_review")
      end

      recommendations
    end

    def packet_recommendation(key, title, detail, severity, status)
      {
        "key" => key,
        "title" => title,
        "detail" => detail,
        "severity" => severity,
        "status" => status
      }
    end
  end
end
