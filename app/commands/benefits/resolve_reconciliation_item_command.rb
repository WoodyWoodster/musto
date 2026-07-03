module Benefits
  class ResolveReconciliationItemCommand < ApplicationCommand
    def initialize(dto:, repository: BenefitsRepository.new(employer: nil))
      @dto = dto
      @repository = repository
    end

    def call
      enrollment = @repository.find_reconciliation_enrollment(@dto.enrollment_id)
      deduction = @repository.resolve_reconciliation_item(enrollment)
      success(record: deduction)
    rescue ActiveRecord::RecordInvalid => e
      failure(record: e.record, errors: e.record.errors.full_messages)
    end
  end
end
