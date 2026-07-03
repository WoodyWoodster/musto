module TimeOff
  class GenerateAccrualPayrollPacketCommand < ApplicationCommand
    def initialize(dto:, employer_repository: Employers::EmployerRepository.new, repository: nil)
      @dto = dto
      @employer = employer_repository.first_for_operations
      @repository = repository || AccrualRepository.new(employer: @employer)
    end

    def call
      return failure(errors: "No employer is available for PTO payroll packet generation") unless @employer

      packet = @repository.generate_payroll_packet(requested_by: @dto.requested_by)
      success(record: @employer.reload, value: packet)
    rescue ActiveRecord::RecordInvalid => e
      failure(record: e.record, errors: e.record.errors.full_messages)
    end
  end
end
