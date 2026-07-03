class VitableEmployerProvisioningController < ApplicationController
  def show
    @provisioning = Vitable::EmployerProvisioningQuery.new.call
  end

  def generate_packet
    dto = Vitable::GenerateEmployerProvisioningDto.from_params(params)
    result = Vitable::GenerateEmployerProvisioningCommand.new(dto:).call

    redirect_to vitable_employer_provisioning_path, notice: result.success? ? "Vitable employer provisioning packet generated." : result.errors.to_sentence
  end

  def submit
    dto = Vitable::SubmitEmployerProvisioningDto.from_params(params)
    result = Vitable::SubmitEmployerProvisioningCommand.new(dto:).call

    redirect_to vitable_employer_provisioning_path, notice: result.success? ? "Vitable employer provisioning submitted." : result.errors.to_sentence
  end
end
