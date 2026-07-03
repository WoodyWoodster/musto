class PerformanceController < ApplicationController
  def show
    @performance = Performance::CenterQuery.new.call
  end

  def launch_cycle
    dto = Performance::LaunchCycleDto.from_params(params)
    result = Performance::LaunchCycleCommand.new(dto:).call

    redirect_to performance_path, notice: result.success? ? "Performance review cycle launched." : result.errors.to_sentence
  end

  def calibrate_review
    dto = Performance::CalibrateReviewDto.from_params(params)
    result = Performance::CalibrateReviewCommand.new(dto:).call

    redirect_to performance_path, notice: result.success? ? "Performance review calibrated." : result.errors.to_sentence
  end

  def complete_goal
    dto = Performance::CompleteGoalDto.from_params(params)
    result = Performance::CompleteGoalCommand.new(dto:).call

    redirect_to performance_path, notice: result.success? ? "Employee goal completed." : result.errors.to_sentence
  end

  def generate_packet
    dto = Performance::GenerateCalibrationPacketDto.from_params(params)
    result = Performance::GenerateCalibrationPacketCommand.new(dto:).call

    redirect_to performance_path, notice: result.success? ? "Performance calibration packet generated." : result.errors.to_sentence
  end
end
