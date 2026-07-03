module Employers
  class OverviewQuery
    def initialize(scope = Employer.all)
      @scope = scope
    end

    def call
      @scope
        .includes(:organization, :employees, :benefit_plans, :enrollments, :payroll_runs)
        .order(created_at: :desc)
    end
  end
end
