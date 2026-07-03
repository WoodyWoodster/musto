module Company
  class SetupRepository < ApplicationRepository
    STEP_KEYS = %w[
      legal_entity
      organization_structure
      workforce_roster
      payroll_settings
      benefits_configuration
      compliance_readiness
      vitable_connection
      launch_review
    ].freeze

    def initialize(employer: nil)
      @employer = employer
    end

    def employer
      @employer
    end

    def departments
      return Department.none unless @employer

      @employer.departments.includes(:manager, :employees).order(:name)
    end

    def locations
      return WorkLocation.none unless @employer

      @employer.work_locations.includes(:employees).order(:name)
    end

    def employees
      return Employee.none unless @employer

      @employer.employees.includes(:department, :work_location, :employee_documents, :enrollments).order(:last_name, :first_name)
    end

    def benefit_plans
      return BenefitPlan.none unless @employer

      @employer.benefit_plans.order(:name)
    end

    def payroll_runs
      return PayrollRun.none unless @employer

      @employer.payroll_runs.order(pay_date: :desc)
    end

    def compliance_cases
      return ComplianceCase.none unless @employer

      @employer.compliance_cases.order(:due_on)
    end

    def vitable_connection
      @employer&.organization&.integration_connections&.find { |connection| connection.provider == "vitable" }
    end

    def completed_steps
      @employer&.settings.to_h.fetch("setup_steps", {}) || {}
    end

    def complete_step(step_key)
      raise ArgumentError, "Unsupported setup step" unless STEP_KEYS.include?(step_key)

      settings = @employer.settings.to_h.deep_dup
      settings["setup_steps"] = settings.fetch("setup_steps", {}).merge(
        step_key => {
          "completed_at" => Time.current.iso8601,
          "completed_by" => "ops_console"
        }
      )

      @employer.update!(settings:)
      @employer
    end
  end
end
