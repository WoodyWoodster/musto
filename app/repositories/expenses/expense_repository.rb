module Expenses
  class ExpenseRepository < ApplicationRepository
    def initialize(employer: nil)
      @employer = employer
    end

    def expenses
      return EmployeeExpense.none unless @employer

      EmployeeExpense
        .joins(:employee)
        .where(employees: { employer_id: @employer.id })
        .includes(employee: [ :department, :work_location ])
        .order(incurred_on: :desc, created_at: :desc)
    end

    def batches
      payload = @employer&.settings.to_h.fetch("expense_reimbursement_batch", nil)
      payload.present? ? [ payload ] : []
    end

    def find_expense(id)
      EmployeeExpense.includes(employee: [ :department, :work_location ]).find(id)
    end

    def approve_expense(expense, reviewed_by:)
      unless expense.policy_ready?
        expense.update!(
          metadata: expense.metadata.to_h.merge(
            "approval_block_reason" => expense.approval_block_reason,
            "approval_blocked_at" => Time.current.iso8601
          )
        )
        return false
      end

      expense.approve!(reviewed_by:)
    end

    def generate_reimbursement_batch(requested_by:)
      eligible_expenses = expenses.where.not(status: "reimbursed").to_a
      approved_expenses = eligible_expenses.select(&:approved?)
      holdbacks = eligible_expenses.reject(&:approved?)
      lines = reimbursement_lines(approved_expenses)

      batch = {
        "batch_id" => "expense_reimbursements_#{@employer.id}_#{Time.current.to_i}",
        "generated_at" => Time.current.iso8601,
        "requested_by" => requested_by,
        "employer_id" => @employer.id,
        "status" => lines.any? && holdbacks.empty? ? "ready" : "needs_review",
        "totals" => {
          "reimbursement_count" => lines.count,
          "employee_count" => approved_expenses.map(&:employee_id).uniq.count,
          "holdback_count" => holdbacks.count,
          "total_cents" => lines.sum { |line| line.fetch("amount_cents") }
        },
        "reimbursements" => lines,
        "holdbacks" => holdbacks.map { |expense| holdback_line(expense) }
      }

      ActiveRecord::Base.transaction do
        @employer.update!(settings: @employer.settings.to_h.merge("expense_reimbursement_batch" => batch))
        approved_expenses.each { |expense| expense.mark_reimbursed!(batch_id: batch.fetch("batch_id")) }
      end

      batch
    end

    private

    def reimbursement_lines(expenses)
      expenses.map do |expense|
        employee = expense.employee

        {
          "expense_id" => expense.id,
          "employee_id" => expense.employee_id,
          "employee_name" => employee.full_name,
          "department_name" => employee.department&.name || "Unassigned",
          "merchant" => expense.merchant,
          "category" => expense.category,
          "incurred_on" => expense.incurred_on.iso8601,
          "payment_method" => expense.payment_method,
          "amount_cents" => expense.amount_cents
        }
      end
    end

    def holdback_line(expense)
      {
        "expense_id" => expense.id,
        "employee_id" => expense.employee_id,
        "employee_name" => expense.employee.full_name,
        "merchant" => expense.merchant,
        "category" => expense.category,
        "status" => expense.status,
        "amount_cents" => expense.amount_cents,
        "reason" => holdback_reason(expense)
      }
    end

    def holdback_reason(expense)
      return expense.approval_block_reason unless expense.approved?
      return "Receipt is missing" unless expense.receipt_ready?
      return "Expense is marked non-reimbursable" unless expense.reimbursable?

      "Ready"
    end
  end
end
