module OpenEnrollment
  class SendRemindersCommand < ApplicationCommand
    def initialize(dto:, employer_repository: Employers::EmployerRepository.new)
      @dto = dto
      @employer = employer_repository.first_for_operations
      @repository = CampaignRepository.new(employer: @employer)
    end

    def call
      return failure(errors: "No employer is available for open enrollment reminders") unless @employer

      batch = @repository.send_reminders(requested_by: @dto.requested_by)
      success(record: @repository.current_campaign, value: batch)
    rescue ActiveRecord::RecordInvalid => e
      failure(record: e.record, errors: e.record.errors.full_messages)
    end
  end
end
