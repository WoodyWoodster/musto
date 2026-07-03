class LifecycleController < ApplicationController
  def show
    @lifecycle = Lifecycle::CommandCenterQuery.new.call
  end

  def approve_event
    dto = Lifecycle::ApproveEventDto.from_params(params)
    result = Lifecycle::ApproveEventCommand.new(dto:).call

    redirect_to lifecycle_path, notice: result.success? ? "Lifecycle event approved." : result.errors.to_sentence
  end

  def generate_batch
    dto = Lifecycle::GenerateSyncBatchDto.from_params(params)
    result = Lifecycle::GenerateSyncBatchCommand.new(dto:).call

    redirect_to lifecycle_path, notice: result.success? ? "Lifecycle sync batch generated." : result.errors.to_sentence
  end
end
