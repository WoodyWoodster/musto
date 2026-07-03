module Performance
  class CompleteGoalCommand < ApplicationCommand
    def initialize(dto:, employer_repository: Employers::EmployerRepository.new, repository: nil)
      @dto = dto
      @employer = employer_repository.first_for_operations
      @repository = repository || PerformanceRepository.new(employer: @employer)
    end

    def call
      return failure(errors: "No employer is available for goal completion") unless @employer

      goal = @repository.find_goal(@dto.goal_id)
      return failure(record: goal, errors: "Employee goal is already complete") unless @repository.complete_goal(goal, reviewed_by: @dto.reviewed_by)

      success(record: goal)
    rescue ActiveRecord::RecordNotFound
      failure(errors: "Employee goal was not found")
    rescue ActiveRecord::RecordInvalid => e
      failure(record: e.record, errors: e.record.errors.full_messages)
    end
  end
end
