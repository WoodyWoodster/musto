module PayStatements
  class GenerateBatchCommand < ApplicationCommand
    def initialize(dto:, employer_repository: Employers::EmployerRepository.new)
      @dto = dto
      @employer = employer_repository.first_for_operations
      @repository = StatementRepository.new(employer: @employer)
    end

    def call
      return failure(errors: "No employer is available for pay statement generation") unless @employer

      batch = @repository.generate_batch(requested_by: @dto.requested_by)
      success(record: @employer.reload, value: batch)
    rescue ActiveRecord::RecordInvalid => e
      failure(record: e.record, errors: e.record.errors.full_messages)
    end
  end
end
