module TimeTracking
  class ReviewEntryCommand < ApplicationCommand
    def initialize(dto:, repository: TimeTrackingRepository.new)
      @dto = dto
      @repository = repository
    end

    def call
      entry = @repository.find_entry(@dto.entry_id)
      @repository.review_entry(entry, decision: @dto.decision, reviewed_by: @dto.reviewed_by)
      success(record: entry.reload)
    rescue ActiveRecord::RecordInvalid => e
      failure(record: e.record, errors: e.record.errors.full_messages)
    end
  end
end
