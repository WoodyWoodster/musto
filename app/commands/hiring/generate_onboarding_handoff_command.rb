module Hiring
  class GenerateOnboardingHandoffCommand < ApplicationCommand
    def initialize(dto:, employer_repository: Employers::EmployerRepository.new)
      @dto = dto
      @employer = employer_repository.first_for_operations
      @repository = HiringRepository.new(employer: @employer)
    end

    def call
      return failure(errors: "No employer is available for hiring handoff") unless @employer

      batch = @repository.generate_onboarding_handoff(requested_by: @dto.requested_by)
      success(record: @employer, value: batch)
    rescue ActiveRecord::RecordInvalid => e
      failure(record: e.record, errors: e.record.errors.full_messages)
    end
  end
end
