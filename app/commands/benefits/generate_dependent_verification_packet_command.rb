module Benefits
  class GenerateDependentVerificationPacketCommand < ApplicationCommand
    def initialize(dto:, employer_repository: Employers::EmployerRepository.new, repository: nil)
      @dto = dto
      @employer = employer_repository.first_for_operations
      @repository = repository || DependentVerificationRepository.new(employer: @employer)
    end

    def call
      return failure(errors: "No employer is available for dependent verification packet generation") unless @employer

      packet = @repository.generate_packet(requested_by: @dto.requested_by)
      success(record: @employer.reload, value: packet)
    rescue ActiveRecord::RecordInvalid => e
      failure(record: e.record, errors: e.record.errors.full_messages)
    end
  end
end
