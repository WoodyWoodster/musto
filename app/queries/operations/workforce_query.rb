module Operations
  class WorkforceQuery
    def initialize(employer: Employer.includes(:organization).order(:created_at).first)
      @employer = employer
    end

    def call
      {
        employer: @employer,
        departments: departments,
        locations: locations,
        employees: employees.includes(:department, :work_location, :enrollments, :onboarding_tasks),
        onboarding_tasks: onboarding_tasks.includes(employee: [ :department ]).order(:due_on),
        documents: documents.includes(:employee).order(:expires_on)
      }
    end

    private

    def departments
      return Department.none unless @employer

      @employer.departments
    end

    def locations
      return WorkLocation.none unless @employer

      @employer.work_locations
    end

    def employees
      return Employee.none unless @employer

      @employer.employees
    end

    def onboarding_tasks
      OnboardingTask.joins(:employee).where(employees: { employer_id: @employer&.id })
    end

    def documents
      EmployeeDocument.joins(:employee).where(employees: { employer_id: @employer&.id })
    end
  end
end
