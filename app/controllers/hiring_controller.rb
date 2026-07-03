class HiringController < ApplicationController
  def show
    @hiring = Hiring::CenterQuery.new.call
  end

  def send_offer
    dto = Hiring::SendOfferDto.from_params(params)
    result = Hiring::SendOfferCommand.new(dto:).call

    redirect_to hiring_path, notice: result.success? ? "Candidate offer sent." : result.errors.to_sentence
  end

  def generate_handoff
    dto = Hiring::GenerateOnboardingHandoffDto.from_params(params)
    result = Hiring::GenerateOnboardingHandoffCommand.new(dto:).call

    redirect_to hiring_path, notice: result.success? ? "Hiring onboarding handoff generated." : result.errors.to_sentence
  end
end
