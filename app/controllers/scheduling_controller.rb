class SchedulingController < ApplicationController
  def show
    @schedule = Scheduling::CenterQuery.new.call
  end

  def publish
    dto = Scheduling::PublishScheduleDto.from_params(params)
    result = Scheduling::PublishScheduleCommand.new(dto:).call

    redirect_to scheduling_path, notice: result.success? ? "Schedule published." : result.errors.to_sentence
  end

  def approve_swap
    dto = Scheduling::ApproveSwapDto.from_params(params)
    result = Scheduling::ApproveSwapCommand.new(dto:).call

    redirect_to scheduling_path, notice: result.success? ? "Shift swap approved." : result.errors.to_sentence
  end

  def generate_forecast
    dto = Scheduling::GenerateForecastDto.from_params(params)
    result = Scheduling::GenerateForecastCommand.new(dto:).call

    redirect_to scheduling_path, notice: result.success? ? "Schedule payroll forecast generated." : result.errors.to_sentence
  end
end
