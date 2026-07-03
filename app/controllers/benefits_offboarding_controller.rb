class BenefitsOffboardingController < ApplicationController
  def show
    @offboarding = Benefits::OffboardingQuery.new.call
  end

  def generate_packet
    dto = Benefits::GenerateOffboardingPacketDto.from_params(params)
    result = Benefits::GenerateOffboardingPacketCommand.new(dto:).call

    redirect_to benefits_offboarding_path, notice: result.success? ? "Benefits offboarding packet generated." : result.errors.to_sentence
  end
end
