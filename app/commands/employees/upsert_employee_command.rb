module Employees
  class UpsertEmployeeCommand < ApplicationCommand
    def initialize(dto:, repository: EmployeeRepository.new)
      @dto = dto
      @repository = repository
    end

    def call
      employee = @repository.upsert(@dto)

      if employee.persisted?
        success(record: employee)
      else
        failure(record: employee, errors: employee.errors.full_messages)
      end
    end
  end
end
