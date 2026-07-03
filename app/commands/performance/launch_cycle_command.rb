module Performance
  class LaunchCycleCommand < ApplicationCommand
    def initialize(dto:, employer_repository: Employers::EmployerRepository.new, repository: nil)
      @dto = dto
      @employer = employer_repository.first_for_operations
      @repository = repository || PerformanceRepository.new(employer: @employer)
    end

    def call
      return failure(errors: "No employer is available for performance cycle launch") unless @employer

      cycle = @repository.launch_cycle(requested_by: @dto.requested_by)
      success(record: cycle)
    rescue ActiveRecord::RecordInvalid => e
      failure(record: e.record, errors: e.record.errors.full_messages)
    end
  end
end
