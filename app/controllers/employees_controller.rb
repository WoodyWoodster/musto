class EmployeesController < ApplicationController
  def show
    @employee = Employees::DetailQuery.new.call(params[:id])
  end
end
