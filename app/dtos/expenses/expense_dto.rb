module Expenses
  ExpenseDto = Data.define(
    :id,
    :employee_id,
    :employee_name,
    :department_name,
    :location_name,
    :incurred_on,
    :merchant,
    :category,
    :description,
    :amount_cents,
    :status,
    :receipt_status,
    :reimbursable,
    :payment_method,
    :approved_at,
    :policy_status,
    :block_reason
  ) do
    def self.from_record(record)
      employee = record.employee

      new(
        id: record.id,
        employee_id: record.employee_id,
        employee_name: employee.full_name,
        department_name: employee.department&.name || "Unassigned",
        location_name: employee.work_location&.name || "No location",
        incurred_on: record.incurred_on,
        merchant: record.merchant,
        category: record.category,
        description: record.description,
        amount_cents: record.amount_cents,
        status: record.status,
        receipt_status: record.receipt_status,
        reimbursable: record.reimbursable?,
        payment_method: record.payment_method,
        approved_at: record.approved_at,
        policy_status: policy_status_for(record),
        block_reason: record.approval_block_reason
      )
    end

    def submitted?
      status == "submitted"
    end

    def approved?
      status == "approved"
    end

    def reimbursed?
      status == "reimbursed"
    end

    def receipt_ready?
      %w[uploaded verified].include?(receipt_status)
    end

    def policy_ready?
      submitted? && reimbursable && receipt_ready?
    end

    def self.policy_status_for(record)
      return "reimbursed" if record.reimbursed?
      return "ready_for_batch" if record.approved?
      return "ready" if record.policy_ready?
      return "blocked" unless record.reimbursable?
      return "needs_receipt" unless record.receipt_ready?

      "needs_review"
    end
  end
end
