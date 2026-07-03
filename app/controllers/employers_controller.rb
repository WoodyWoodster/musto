class EmployersController < ApplicationController
  def index
    @employers = Employers::OverviewQuery.new.call
  end

  def show
    @employer = Employers::DetailQuery.new.call(params[:id])
  end
end
