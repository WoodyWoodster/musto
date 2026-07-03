module Benefits
  class EligibilityRepository < ApplicationRepository
    def initialize(employer: nil)
      @employer = employer
    end

    def employees
      return Employee.none unless @employer

      @employer.employees.active.includes(:department, :work_location, :dependents, enrollments: [ :benefit_plan ]).order(:last_name, :first_name)
    end

    def dependents
      return Dependent.none unless @employer

      Dependent
        .joins(:employee)
        .where(employees: { employer_id: @employer.id })
        .includes(employee: [ :department, :work_location ])
        .order(:last_name, :first_name)
    end

    def enrollments
      return Enrollment.none unless @employer

      Enrollment
        .joins(:employee)
        .where(employees: { employer_id: @employer.id })
        .includes(:benefit_plan, employee: [ :department, :work_location, :dependents ])
        .order(effective_on: :desc, created_at: :desc)
    end

    def accepted_enrollments
      enrollments.accepted
    end

    def batches
      payload = @employer&.settings.to_h.fetch("vitable_eligibility_batch", nil)
      payload.present? ? [ payload ] : []
    end

    def generate_batch(requested_by:)
      accepted = accepted_enrollments.to_a
      member_lines = accepted.flat_map { |enrollment| member_lines_for(enrollment) }
      holdbacks = enrollment_holdbacks(enrollments.to_a) + dependent_holdbacks(dependents.to_a)
      batch = {
        "batch_id" => "vitable_eligibility_#{@employer.id}_#{Time.current.to_i}",
        "generated_at" => Time.current.iso8601,
        "requested_by" => requested_by,
        "employer_id" => @employer.id,
        "status" => holdbacks.any? ? "needs_review" : "ready",
        "totals" => {
          "member_count" => member_lines.count,
          "employee_count" => member_lines.count { |line| line.fetch("member_type") == "employee" },
          "dependent_count" => member_lines.count { |line| line.fetch("member_type") == "dependent" },
          "holdback_count" => holdbacks.count
        },
        "members" => member_lines,
        "holdbacks" => holdbacks
      }

      @employer.update!(settings: @employer.settings.to_h.merge("vitable_eligibility_batch" => batch))
      batch
    end

    private

    def member_lines_for(enrollment)
      return [] if enrollment.effective_on.blank?

      [ employee_member_line(enrollment) ] + enrollment.employee.dependents.select(&:eligible?).map do |dependent|
        dependent_member_line(enrollment, dependent)
      end
    end

    def employee_member_line(enrollment)
      employee = enrollment.employee

      {
        "member_id" => "employee_#{employee.id}_enrollment_#{enrollment.id}",
        "member_type" => "employee",
        "employee_id" => employee.id,
        "dependent_id" => nil,
        "name" => employee.full_name,
        "relationship" => "employee",
        "plan_name" => enrollment.benefit_plan.name,
        "plan_category" => enrollment.benefit_plan.category,
        "coverage_level" => enrollment.coverage_level,
        "effective_on" => enrollment.effective_on.iso8601,
        "remote_member_id" => employee.vitable_id.presence || "pending_employee_#{employee.id}",
        "remote_enrollment_id" => enrollment.vitable_id.presence || "pending_enrollment_#{enrollment.id}",
        "status" => "eligible"
      }
    end

    def dependent_member_line(enrollment, dependent)
      {
        "member_id" => "dependent_#{dependent.id}_enrollment_#{enrollment.id}",
        "member_type" => "dependent",
        "employee_id" => enrollment.employee_id,
        "dependent_id" => dependent.id,
        "name" => dependent.full_name,
        "relationship" => dependent.relationship,
        "plan_name" => enrollment.benefit_plan.name,
        "plan_category" => enrollment.benefit_plan.category,
        "coverage_level" => enrollment.coverage_level,
        "effective_on" => enrollment.effective_on.iso8601,
        "remote_member_id" => dependent.vitable_id.presence || "pending_dependent_#{dependent.id}",
        "remote_enrollment_id" => enrollment.vitable_id.presence || "pending_enrollment_#{enrollment.id}",
        "status" => "eligible"
      }
    end

    def enrollment_holdbacks(enrollments)
      enrollments.reject { |enrollment| enrollment.status == "accepted" && enrollment.effective_on.present? }.map do |enrollment|
        {
          "source_type" => "enrollment",
          "source_id" => enrollment.id,
          "employee_id" => enrollment.employee_id,
          "employee_name" => enrollment.employee.full_name,
          "label" => enrollment.benefit_plan.name,
          "status" => enrollment.status,
          "reason" => enrollment.status == "accepted" ? "Effective date is missing" : "Enrollment is not accepted"
        }
      end
    end

    def dependent_holdbacks(dependents)
      dependents.reject(&:eligible?).map do |dependent|
        {
          "source_type" => "dependent",
          "source_id" => dependent.id,
          "employee_id" => dependent.employee_id,
          "employee_name" => dependent.employee.full_name,
          "label" => dependent.full_name,
          "status" => dependent.eligibility_status,
          "reason" => dependent.enrolled? ? "Dependent eligibility needs review" : "Dependent enrollment is not complete"
        }
      end
    end
  end
end
