module Payroll
  class GenerateBenefitsExportCommand < ApplicationCommand
    def initialize(dto:, repository: PayrollRepository.new)
      @dto = dto
      @repository = repository
    end

    def call
      run = @repository.find_export_detail(@dto.payroll_run_id)
      payload = @repository.generate_benefits_export(run)
      success(record: run.reload, value: payload)
    rescue ActiveRecord::RecordInvalid => e
      failure(record: e.record, errors: e.record.errors.full_messages)
    end
  end
end
