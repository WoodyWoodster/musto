module Company
  class CompleteSetupStepCommand < ApplicationCommand
    def initialize(dto:, employer_repository: Employers::EmployerRepository.new)
      @dto = dto
      @employer = employer_repository.first_for_operations
      @repository = SetupRepository.new(employer: @employer)
    end

    def call
      employer = @repository.complete_step(@dto.step_key)
      success(record: employer)
    rescue ActiveRecord::RecordInvalid => e
      failure(record: e.record, errors: e.record.errors.full_messages)
    rescue ArgumentError => e
      failure(errors: e.message)
    end
  end
end
