module Benefits
  class ApproveBillingInvoiceCommand < ApplicationCommand
    def initialize(dto:, repository: BillingRepository.new)
      @dto = dto
      @repository = repository
    end

    def call
      invoice = @repository.find_invoice(@dto.invoice_id)
      @repository.approve_invoice(invoice, reviewed_by: @dto.reviewed_by)

      success(record: invoice)
    rescue ActiveRecord::RecordInvalid => e
      failure(record: e.record, errors: e.record.errors.full_messages)
    rescue ActiveRecord::RecordNotFound => e
      failure(errors: e.message)
    end
  end
end
