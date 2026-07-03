class PayrollCalendarController < ApplicationController
  def show
    @calendar = PayrollCalendar::CenterQuery.new.call
  end

  def generate_checklist
    dto = PayrollCalendar::GenerateChecklistDto.from_params(params)
    result = PayrollCalendar::GenerateChecklistCommand.new(dto:).call

    redirect_to payroll_calendar_path, notice: result.success? ? "Payroll approval checklist generated." : result.errors.to_sentence
  end

  def complete_step
    dto = PayrollCalendar::CompleteStepDto.from_params(params)
    result = PayrollCalendar::CompleteStepCommand.new(dto:).call

    redirect_to payroll_calendar_path, notice: result.success? ? "Payroll approval step completed." : result.errors.to_sentence
  end
end
