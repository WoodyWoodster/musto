class BenefitsEligibilityController < ApplicationController
  def show
    @eligibility = Benefits::EligibilityQuery.new.call
  end

  def generate_batch
    dto = Benefits::GenerateEligibilityBatchDto.from_params(params)
    result = Benefits::GenerateEligibilityBatchCommand.new(dto:).call

    redirect_to benefits_eligibility_path, notice: result.success? ? "Benefits eligibility batch generated." : result.errors.to_sentence
  end
end
