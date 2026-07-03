module Performance
  class CalibrateReviewCommand < ApplicationCommand
    def initialize(dto:, employer_repository: Employers::EmployerRepository.new, repository: nil)
      @dto = dto
      @employer = employer_repository.first_for_operations
      @repository = repository || PerformanceRepository.new(employer: @employer)
    end

    def call
      return failure(errors: "No employer is available for performance calibration") unless @employer

      review = @repository.find_review(@dto.review_id)
      return failure(record: review, errors: "Performance review is not ready for calibration") unless @repository.calibrate_review(review, calibrated_by: @dto.calibrated_by)

      success(record: review)
    rescue ActiveRecord::RecordNotFound
      failure(errors: "Performance review was not found")
    rescue ActiveRecord::RecordInvalid => e
      failure(record: e.record, errors: e.record.errors.full_messages)
    end
  end
end
