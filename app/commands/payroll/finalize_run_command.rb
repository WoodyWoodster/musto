module Payroll
  class FinalizeRunCommand < ApplicationCommand
    def initialize(dto:, repository: PayrollRepository.new)
      @dto = dto
      @repository = repository
    end

    def call
      payroll_run = @repository.find_run(@dto.payroll_run_id)
      return failure(record: payroll_run, errors: "Payroll run is already finalized") if payroll_run.status == "finalized"

      @repository.finalize(payroll_run)
      success(record: payroll_run)
    rescue ActiveRecord::RecordInvalid => e
      failure(record: e.record, errors: e.record.errors.full_messages)
    end
  end
end
