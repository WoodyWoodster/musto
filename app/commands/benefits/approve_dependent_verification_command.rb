module Benefits
  class ApproveDependentVerificationCommand < ApplicationCommand
    def initialize(dto:, employer_repository: Employers::EmployerRepository.new, repository: nil)
      @dto = dto
      @employer = employer_repository.first_for_operations
      @repository = repository || DependentVerificationRepository.new(employer: @employer)
    end

    def call
      return failure(errors: "No employer is available for dependent verification approval") unless @employer

      verification = @repository.find_verification(@dto.verification_id)
      @repository.approve_verification(verification, reviewed_by: @dto.reviewed_by)
      success(record: verification.reload)
    rescue ActiveRecord::RecordNotFound
      failure(errors: "Dependent verification was not found")
    rescue ActiveRecord::RecordInvalid => e
      failure(record: e.record, errors: e.record.errors.full_messages)
    end
  end
end
