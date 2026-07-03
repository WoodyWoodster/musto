class TrainingController < ApplicationController
  def show
    @training = Training::CenterQuery.new.call
  end

  def launch_program
    dto = Training::LaunchProgramDto.from_params(params)
    result = Training::LaunchProgramCommand.new(dto:).call

    redirect_to training_path, notice: result.success? ? "Training program launched." : result.errors.to_sentence
  end

  def complete_assignment
    dto = Training::CompleteAssignmentDto.from_params(params)
    result = Training::CompleteAssignmentCommand.new(dto:).call

    redirect_to training_path, notice: result.success? ? "Training assignment completed." : result.errors.to_sentence
  end

  def generate_packet
    dto = Training::GenerateAuditPacketDto.from_params(params)
    result = Training::GenerateAuditPacketCommand.new(dto:).call

    redirect_to training_path, notice: result.success? ? "Training audit packet generated." : result.errors.to_sentence
  end
end
