class ExpensesController < ApplicationController
  def show
    @expenses = Expenses::CenterQuery.new.call
  end

  def approve_expense
    dto = Expenses::ApproveExpenseDto.from_params(params)
    result = Expenses::ApproveExpenseCommand.new(dto:).call

    redirect_to expenses_path, notice: result.success? ? "Expense approved for reimbursement." : result.errors.to_sentence
  end

  def generate_batch
    dto = Expenses::GenerateBatchDto.from_params(params)
    result = Expenses::GenerateReimbursementBatchCommand.new(dto:).call

    redirect_to expenses_path, notice: result.success? ? "Expense reimbursement batch generated." : result.errors.to_sentence
  end
end
