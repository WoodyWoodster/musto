class BenefitsDependentVerificationsController < ApplicationController
  def show
    @dependent_verifications = Benefits::DependentVerificationQuery.new.call
  end

  def request_batch
    dto = Benefits::RequestDependentVerificationsDto.from_params(params)
    result = Benefits::RequestDependentVerificationsCommand.new(dto:).call

    redirect_to benefits_dependent_verifications_path, notice: result.success? ? "Dependent verification requests prepared." : result.errors.to_sentence
  end

  def approve
    dto = Benefits::ApproveDependentVerificationDto.from_params(params)
    result = Benefits::ApproveDependentVerificationCommand.new(dto:).call

    redirect_to benefits_dependent_verifications_path, notice: result.success? ? "Dependent verification approved." : result.errors.to_sentence
  end

  def reject
    dto = Benefits::RejectDependentVerificationDto.from_params(params)
    result = Benefits::RejectDependentVerificationCommand.new(dto:).call

    redirect_to benefits_dependent_verifications_path, notice: result.success? ? "Dependent verification rejected." : result.errors.to_sentence
  end

  def generate_packet
    dto = Benefits::GenerateDependentVerificationPacketDto.from_params(params)
    result = Benefits::GenerateDependentVerificationPacketCommand.new(dto:).call

    redirect_to benefits_dependent_verifications_path, notice: result.success? ? "Dependent verification packet generated." : result.errors.to_sentence
  end
end
