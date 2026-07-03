module Employers
  class EmployerRepository < ApplicationRepository
    def first_for_operations
      Employer.includes(:organization).order(:created_at).first
    end

    def overview
      Employer
        .includes(:organization, :employees, :benefit_plans, :enrollments, :payroll_runs, :compliance_cases)
        .order(created_at: :desc)
    end

    def dashboard_portfolio
      overview.limit(6)
    end

    def find_detail(id)
      Employer
        .includes(
          :organization,
          :departments,
          :compliance_cases,
          employees: [ :department, :work_location ],
          benefit_plans: []
        )
        .find(id)
    end

    def find(id)
      Employer.find(id)
    end

    def create(dto)
      Employer.new(dto.to_attributes).tap(&:save)
    end
  end
end
