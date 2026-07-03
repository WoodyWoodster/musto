class EmployeeChangesController < ApplicationController
  def show
    @employee_changes = EmployeeChanges::CenterQuery.new.call
  end

  def approve
    dto = EmployeeChanges::ApproveRequestDto.from_params(params)
    result = EmployeeChanges::ApproveRequestCommand.new(dto:).call

    redirect_to employee_changes_path, notice: result.success? ? "Employee change approved and applied." : result.errors.to_sentence
  end

  def reject
    dto = EmployeeChanges::RejectRequestDto.from_params(params)
    result = EmployeeChanges::RejectRequestCommand.new(dto:).call

    redirect_to employee_changes_path, notice: result.success? ? "Employee change rejected." : result.errors.to_sentence
  end

  def generate_batch
    dto = EmployeeChanges::GenerateSyncBatchDto.from_params(params)
    result = EmployeeChanges::GenerateSyncBatchCommand.new(dto:).call

    redirect_to employee_changes_path, notice: result.success? ? "Employee change sync batch generated." : result.errors.to_sentence
  end
end
