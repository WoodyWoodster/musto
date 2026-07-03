module Training
  class LaunchProgramCommand < ApplicationCommand
    def initialize(dto:, employer_repository: Employers::EmployerRepository.new, repository: nil)
      @dto = dto
      @employer = employer_repository.first_for_operations
      @repository = repository || TrainingRepository.new(employer: @employer)
    end

    def call
      return failure(errors: "No employer is available for training launch") unless @employer

      program = @repository.launch_program(requested_by: @dto.requested_by)
      success(record: program)
    rescue ActiveRecord::RecordInvalid => e
      failure(record: e.record, errors: e.record.errors.full_messages)
    end
  end
end
