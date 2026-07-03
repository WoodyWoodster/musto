class PayrollBenefitsExportsController < ApplicationController
  def show
    @export = Payroll::BenefitsExportQuery.new.call(params[:payroll_run_id])
  end

  def generate
    dto = Payroll::GenerateBenefitsExportDto.from_params(params)
    result = Payroll::GenerateBenefitsExportCommand.new(dto:).call

    redirect_to(
      payroll_run_benefits_export_path(result.record || dto.payroll_run_id),
      notice: result.success? ? "Benefits export generated." : result.errors.to_sentence
    )
  end
end
