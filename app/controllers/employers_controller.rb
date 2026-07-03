class EmployersController < ApplicationController
  def index
    @employers = Employers::OverviewQuery.new.call
  end

  def show
    @employer = Employer
      .includes(:organization, :employees, :benefit_plans, :enrollments, :payroll_runs)
      .find(params[:id])
  end
end
