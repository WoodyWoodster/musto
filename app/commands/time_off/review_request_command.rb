module TimeOff
  class ReviewRequestCommand < ApplicationCommand
    def initialize(dto:, repository: TimeOffRepository.new)
      @dto = dto
      @repository = repository
    end

    def call
      request = @repository.find_time_off_request(@dto.request_id)
      return failure(record: request, errors: "Unsupported decision") unless %w[approved denied].include?(@dto.decision)

      @repository.review_time_off_request(request, @dto.decision)
      success(record: request)
    rescue ActiveRecord::RecordInvalid => e
      failure(record: e.record, errors: e.record.errors.full_messages)
    end
  end
end
