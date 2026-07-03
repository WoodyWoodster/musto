module Compliance
  class AcknowledgeNoticeCommand < ApplicationCommand
    def initialize(dto:, employer_repository: Employers::EmployerRepository.new, repository: nil)
      @dto = dto
      @employer = employer_repository.first_for_operations
      @repository = repository || NoticeRepository.new(employer: @employer)
    end

    def call
      return failure(errors: "No employer is available for compliance notice acknowledgment") unless @employer

      notice = @repository.find_notice(@dto.notice_id)
      return failure(record: notice, errors: "Compliance notice is already resolved") if notice.resolved?

      @repository.acknowledge_notice(notice, acknowledged_by: @dto.acknowledged_by)
      success(record: notice.reload)
    rescue ActiveRecord::RecordNotFound
      failure(errors: "Compliance notice was not found")
    rescue ActiveRecord::RecordInvalid => e
      failure(record: e.record, errors: e.record.errors.full_messages)
    end
  end
end
