module Lifecycle
  class ApproveEventCommand < ApplicationCommand
    def initialize(dto:, repository: LifecycleRepository.new)
      @dto = dto
      @repository = repository
    end

    def call
      event = @repository.find_event(@dto.event_id)
      @repository.approve_event(event, reviewed_by: @dto.reviewed_by)
      success(record: event.reload)
    rescue ActiveRecord::RecordInvalid => e
      failure(record: e.record, errors: e.record.errors.full_messages)
    end
  end
end
