module Workforce
  class WorkforceRepository < ApplicationRepository
    def initialize(employer:)
      @employer = employer
    end

    def departments
      return Department.none unless @employer

      @employer.departments.includes(:employees).order(:name)
    end

    def locations
      return WorkLocation.none unless @employer

      @employer.work_locations.includes(:employees).order(:name)
    end

    def employees
      return Employee.none unless @employer

      @employer.employees.includes(:department, :work_location, :enrollments).order(:last_name, :first_name)
    end

    def onboarding_tasks
      OnboardingTask
        .joins(:employee)
        .where(employees: { employer_id: @employer&.id })
        .includes(employee: [ :department ])
        .order(:due_on)
    end

    def documents
      EmployeeDocument
        .joins(:employee)
        .where(employees: { employer_id: @employer&.id })
        .includes(:employee)
        .order(:expires_on)
    end

    def documents_attention_count
      documents.attention_needed.count
    end

    def open_onboarding_count
      onboarding_tasks.open.count
    end
  end
end
