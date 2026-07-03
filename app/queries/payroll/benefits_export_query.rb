module Payroll
  class BenefitsExportQuery
    def initialize(repository: PayrollRepository.new)
      @repository = repository
    end

    def call(payroll_run_id)
      BenefitsExportDetailDto.from_record(@repository.find_export_detail(payroll_run_id))
    end
  end
end
