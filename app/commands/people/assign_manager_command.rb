module People
  class AssignManagerCommand < ApplicationCommand
    def initialize(dto:, employer_repository: Employers::EmployerRepository.new, repository: nil)
      @dto = dto
      @employer = employer_repository.first_for_operations
      @repository = repository || DirectoryRepository.new(employer: @employer)
    end

    def call
      return failure(errors: "No employer is available for people directory management") unless @employer

      employee = @repository.find_employee(@dto.employee_id)
      manager = @repository.find_manager(@dto.manager_id)
      return failure(record: employee, errors: "Employee cannot report to themselves") unless @repository.assign_manager(employee, manager:, assigned_by: @dto.assigned_by)

      success(record: employee.reload)
    rescue ActiveRecord::RecordNotFound
      failure(errors: "Employee or manager was not found")
    rescue ActiveRecord::RecordInvalid => e
      failure(record: e.record, errors: e.record.errors.full_messages)
    end
  end
end
