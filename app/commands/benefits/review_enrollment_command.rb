module Benefits
  class ReviewEnrollmentCommand < ApplicationCommand
    def initialize(dto:, repository: BenefitsRepository.new(employer: nil))
      @dto = dto
      @repository = repository
    end

    def call
      enrollment = @repository.find(@dto.enrollment_id)
      return failure(record: enrollment, errors: "Unsupported enrollment decision") unless %w[accepted waived].include?(@dto.decision)

      @repository.review_enrollment(enrollment, @dto.decision)
      success(record: enrollment)
    rescue ActiveRecord::RecordInvalid => e
      failure(record: e.record, errors: e.record.errors.full_messages)
    end
  end
end
