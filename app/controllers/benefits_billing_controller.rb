class BenefitsBillingController < ApplicationController
  def show
    @billing = Benefits::BillingQuery.new.call
  end

  def approve_invoice
    dto = Benefits::ApproveBillingInvoiceDto.from_params(params)
    result = Benefits::ApproveBillingInvoiceCommand.new(dto:).call

    redirect_to benefits_billing_path, notice: result.success? ? "Benefit invoice approved." : result.errors.to_sentence
  end

  def generate_packet
    dto = Benefits::GenerateBillingPacketDto.from_params(params)
    result = Benefits::GenerateBillingPacketCommand.new(dto:).call

    redirect_to benefits_billing_path, notice: result.success? ? "Benefit billing packet generated." : result.errors.to_sentence
  end
end
