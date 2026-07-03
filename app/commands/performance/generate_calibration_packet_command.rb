module Performance
  class GenerateCalibrationPacketCommand < ApplicationCommand
    def initialize(dto:, employer_repository: Employers::EmployerRepository.new, repository: nil)
      @dto = dto
      @employer = employer_repository.first_for_operations
      @repository = repository || PerformanceRepository.new(employer: @employer)
    end

    def call
      return failure(errors: "No employer is available for performance calibration packet") unless @employer

      packet = @repository.generate_calibration_packet(requested_by: @dto.requested_by)
      success(record: @employer, value: packet)
    rescue ActiveRecord::RecordInvalid => e
      failure(record: e.record, errors: e.record.errors.full_messages)
    end
  end
end
