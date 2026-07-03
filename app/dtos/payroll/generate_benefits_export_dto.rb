module Payroll
  GenerateBenefitsExportDto = Data.define(:payroll_run_id) do
    def self.from_params(params)
      new(payroll_run_id: ApplicationDto.id_from(params, :payroll_run_id))
    end
  end
end
