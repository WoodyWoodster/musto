class TimesheetsController < ApplicationController
  def show
    @timesheets = TimeTracking::CenterQuery.new.call
  end

  def approve_entry
    review_entry("approved")
  end

  def reject_entry
    review_entry("rejected")
  end

  def generate_export
    dto = TimeTracking::GenerateExportDto.from_params(params)
    result = TimeTracking::GenerateExportCommand.new(dto:).call

    redirect_to timesheets_path, notice: result.success? ? "Timesheet payroll export generated." : result.errors.to_sentence
  end

  private

  def review_entry(decision)
    dto = TimeTracking::ReviewEntryDto.from_params(params, decision:)
    result = TimeTracking::ReviewEntryCommand.new(dto:).call

    redirect_to timesheets_path, notice: result.success? ? "Time entry #{decision}." : result.errors.to_sentence
  end
end
