module Compliance
  class ResolveCaseCommand < ApplicationCommand
    def initialize(dto:, repository: ComplianceRepository.new)
      @dto = dto
      @repository = repository
    end

    def call
      compliance_case = @repository.find_case(@dto.compliance_case_id)
      @repository.resolve_case(compliance_case)
      success(record: compliance_case)
    rescue ActiveRecord::RecordInvalid => e
      failure(record: e.record, errors: e.record.errors.full_messages)
    end
  end
end
