module Garnishments
  class ApproveOrderCommand < ApplicationCommand
    def initialize(dto:, employer_repository: Employers::EmployerRepository.new, repository: nil)
      @dto = dto
      @employer = employer_repository.first_for_operations
      @repository = repository || GarnishmentRepository.new(employer: @employer)
    end

    def call
      return failure(errors: "No employer is available for garnishment approval") unless @employer

      order = @repository.find_order(@dto.id)
      return failure(record: order, errors: "Garnishment order is not approvable") unless @repository.approve_order(order, approved_by: @dto.approved_by)

      success(record: order.reload)
    rescue ActiveRecord::RecordNotFound
      failure(errors: "Garnishment order was not found")
    rescue ActiveRecord::RecordInvalid => e
      failure(record: e.record, errors: e.record.errors.full_messages)
    end
  end
end
