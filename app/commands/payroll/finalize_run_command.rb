module Payroll
  class FinalizeRunCommand < ApplicationCommand
    def initialize(payroll_run:)
      @payroll_run = payroll_run
    end

    def call
      return failure(record: @payroll_run, errors: "Payroll run is already finalized") if @payroll_run.status == "finalized"

      @payroll_run.update!(status: "finalized")
      success(record: @payroll_run)
    rescue ActiveRecord::RecordInvalid => e
      failure(record: @payroll_run, errors: e.record.errors.full_messages)
    end
  end
end
