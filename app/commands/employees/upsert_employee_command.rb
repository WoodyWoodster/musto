module Employees
  class UpsertEmployeeCommand < ApplicationCommand
    def initialize(dto:)
      @dto = dto
    end

    def call
      employee = Employee.find_or_initialize_by(employer_id: @dto.employer_id, email: @dto.email)
      employee.assign_attributes(@dto.to_attributes)

      if employee.save
        success(record: employee)
      else
        failure(record: employee, errors: employee.errors.full_messages)
      end
    end
  end
end
