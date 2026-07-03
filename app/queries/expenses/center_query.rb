module Expenses
  class CenterQuery
    def initialize(employer_repository: Employers::EmployerRepository.new)
      @employer = employer_repository.first_for_operations
      @repository = ExpenseRepository.new(employer: @employer)
    end

    def call
      expense_records = @repository.expenses.to_a
      batches = @repository.batches
      latest_batch = batches.first.to_h

      CenterDto.new(
        employer: Operations::EmployerContextDto.from_record(@employer),
        metrics: metrics(expense_records),
        expenses: expense_records.map { |expense| ExpenseDto.from_record(expense) },
        policy_items: policy_items(expense_records),
        batches: batches.map { |payload| BatchDto.from_hash(payload) },
        batch_lines: latest_batch.fetch("reimbursements", []).map { |payload| BatchLineDto.from_hash(payload) },
        batch_holdbacks: latest_batch.fetch("holdbacks", []).map { |payload| BatchHoldbackDto.from_hash(payload) },
        batch_payload: batches.first
      )
    end

    private

    def metrics(expenses)
      submitted_count = expenses.count(&:submitted?)
      approved_total = expenses.select(&:approved?).sum(&:amount_cents)
      reimbursed_total = expenses.select(&:reimbursed?).sum(&:amount_cents)
      receipt_issues = expenses.count { |expense| expense.submitted? && !expense.receipt_ready? }

      [
        MetricDto.new(label: "Review queue", value: submitted_count, hint: "submitted expenses need action", status: submitted_count.positive? ? "needs_review" : "ready", accent: "bg-orange-500", format: "number"),
        MetricDto.new(label: "Approved reimbursements", value: approved_total, hint: "ready for payroll batch", status: approved_total.positive? ? "ready" : "needs_review", accent: "bg-emerald-500", format: "money"),
        MetricDto.new(label: "Reimbursed", value: reimbursed_total, hint: "paid through generated batches", status: reimbursed_total.positive? ? "ready" : "needs_review", accent: "bg-indigo-500", format: "money"),
        MetricDto.new(label: "Receipt issues", value: receipt_issues, hint: "missing receipts block approval", status: receipt_issues.positive? ? "blocked" : "ready", accent: "bg-rose-500", format: "number")
      ]
    end

    def policy_items(expenses)
      routes = Rails.application.routes.url_helpers
      items = []
      missing_receipts = expenses.select { |expense| expense.submitted? && !expense.receipt_ready? }
      non_reimbursable = expenses.select { |expense| expense.submitted? && !expense.reimbursable? }
      review_ready = expenses.select(&:policy_ready?)
      approved = expenses.select(&:approved?)

      if missing_receipts.any?
        items << PolicyItemDto.new(key: "missing_receipts", title: "Collect missing receipts", detail: "#{missing_receipts.count} submitted expenses need uploaded or verified receipts before approval.", severity: "high", status: "blocked", owner: "Finance", count: missing_receipts.count, amount_cents: missing_receipts.sum(&:amount_cents), action_path: routes.expenses_path)
      end

      if non_reimbursable.any?
        items << PolicyItemDto.new(key: "non_reimbursable", title: "Resolve out-of-policy expenses", detail: "#{non_reimbursable.count} expenses are marked non-reimbursable and should be rejected or corrected before payroll.", severity: "medium", status: "needs_review", owner: "People Ops", count: non_reimbursable.count, amount_cents: non_reimbursable.sum(&:amount_cents), action_path: routes.expenses_path)
      end

      if review_ready.any?
        items << PolicyItemDto.new(key: "ready_for_approval", title: "Approve policy-ready expenses", detail: "#{review_ready.count} expenses have receipts and are eligible for reimbursement approval.", severity: "medium", status: "needs_review", owner: "Finance", count: review_ready.count, amount_cents: review_ready.sum(&:amount_cents), action_path: routes.expenses_path)
      end

      if approved.any?
        items << PolicyItemDto.new(key: "ready_for_batch", title: "Generate reimbursement batch", detail: "#{approved.count} approved expenses can be moved into the next payroll reimbursement batch.", severity: "low", status: "ready", owner: "Payroll", count: approved.count, amount_cents: approved.sum(&:amount_cents), action_path: routes.generate_expense_reimbursement_batch_path)
      end

      return items if items.any?

      [
        PolicyItemDto.new(key: "expenses_ready", title: "Expense reimbursements are clear", detail: "No open receipt, approval, or reimbursement exceptions are waiting on the finance team.", severity: "low", status: "ready", owner: "Finance", count: 0, amount_cents: 0, action_path: routes.expenses_path)
      ]
    end
  end
end
