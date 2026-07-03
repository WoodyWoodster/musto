class BenefitsPlanAdminController < ApplicationController
  def show
    @plan_admin = Benefits::PlanAdministrationQuery.new.call
  end

  def publish
    dto = Benefits::PublishPlanDto.from_params(params)
    result = Benefits::PublishPlanCommand.new(dto:).call

    redirect_to benefits_plan_admin_path, notice: result.success? ? "Benefit plan published." : result.errors.to_sentence
  end

  def generate_packet
    dto = Benefits::GeneratePlanCatalogPacketDto.from_params(params)
    result = Benefits::GeneratePlanCatalogPacketCommand.new(dto:).call

    redirect_to benefits_plan_admin_path, notice: result.success? ? "Benefit plan catalog packet generated." : result.errors.to_sentence
  end
end
