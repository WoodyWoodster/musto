module Expenses
  class ApproveExpenseCommand < ApplicationCommand
    def initialize(dto:, repository: ExpenseRepository.new)
      @dto = dto
      @repository = repository
    end

    def call
      expense = @repository.find_expense(@dto.expense_id)

      if @repository.approve_expense(expense, reviewed_by: @dto.reviewed_by)
        success(record: expense.reload)
      else
        failure(record: expense.reload, errors: expense.approval_block_reason)
      end
    rescue ActiveRecord::RecordInvalid => e
      failure(record: e.record, errors: e.record.errors.full_messages)
    end
  end
end
