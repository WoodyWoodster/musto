module Benefits
  class RequestDependentVerificationsCommand < ApplicationCommand
    def initialize(dto:, employer_repository: Employers::EmployerRepository.new, repository: nil)
      @dto = dto
      @employer = employer_repository.first_for_operations
      @repository = repository || DependentVerificationRepository.new(employer: @employer)
    end

    def call
      return failure(errors: "No employer is available for dependent verification requests") unless @employer

      verifications = @repository.request_missing_verifications(requested_by: @dto.requested_by)
      success(record: @employer, value: verifications)
    rescue ActiveRecord::RecordInvalid => e
      failure(record: e.record, errors: e.record.errors.full_messages)
    end
  end
end
