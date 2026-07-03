module TimeOff
  class ReviewRequestCommand < ApplicationCommand
    def initialize(request:, decision:)
      @request = request
      @decision = decision
    end

    def call
      return failure(record: @request, errors: "Unsupported decision") unless %w[approved denied].include?(@decision)

      @request.update!(status: @decision, reviewed_at: Time.current)
      success(record: @request)
    rescue ActiveRecord::RecordInvalid => e
      failure(record: @request, errors: e.record.errors.full_messages)
    end
  end
end
