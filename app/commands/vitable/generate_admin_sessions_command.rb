module Vitable
  class GenerateAdminSessionsCommand < ApplicationCommand
    def initialize(dto:, employer_repository: Employers::EmployerRepository.new)
      @dto = dto
      @employer = employer_repository.first_for_operations
      @repository = AdminSessionsRepository.new(employer: @employer)
    end

    def call
      return failure(errors: "No employer is available for employer admin sessions") unless @employer

      packet = @repository.generate_packet(requested_by: @dto.requested_by)
      success(record: @employer.reload, value: packet)
    rescue ActiveRecord::RecordInvalid => e
      failure(record: e.record, errors: e.record.errors.full_messages)
    end
  end
end
