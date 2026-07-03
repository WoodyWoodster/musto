module Training
  class CompleteAssignmentCommand < ApplicationCommand
    def initialize(dto:, employer_repository: Employers::EmployerRepository.new, repository: nil)
      @dto = dto
      @employer = employer_repository.first_for_operations
      @repository = repository || TrainingRepository.new(employer: @employer)
    end

    def call
      return failure(errors: "No employer is available for training completion") unless @employer

      assignment = @repository.find_assignment(@dto.id)
      return failure(record: assignment, errors: "Training assignment is already complete") unless assignment.completable?

      @repository.complete_assignment(assignment, completed_by: @dto.completed_by, score: @dto.score)
      success(record: assignment)
    rescue ActiveRecord::RecordNotFound
      failure(errors: "Training assignment was not found")
    rescue ActiveRecord::RecordInvalid => e
      failure(record: e.record, errors: e.record.errors.full_messages)
    end
  end
end
