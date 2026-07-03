module Contractors
  class ApprovePaymentCommand < ApplicationCommand
    def initialize(dto:, repository: ContractorRepository.new)
      @dto = dto
      @repository = repository
    end

    def call
      payment = @repository.find_payment(@dto.payment_id)

      if @repository.approve_payment(payment, reviewed_by: @dto.reviewed_by)
        success(record: payment.reload)
      else
        failure(record: payment.reload, errors: "Contractor tax form and verified payment method are required before approval")
      end
    rescue ActiveRecord::RecordInvalid => e
      failure(record: e.record, errors: e.record.errors.full_messages)
    end
  end
end
