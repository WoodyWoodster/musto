class EmployeeExpense < ApplicationRecord
  STATUSES = %w[submitted approved rejected reimbursed].freeze
  RECEIPT_STATUSES = %w[missing uploaded verified].freeze
  PAYMENT_METHODS = %w[employee_paid company_card mileage].freeze

  belongs_to :employee

  validates :incurred_on, :merchant, :category, :status, :receipt_status, :payment_method, presence: true
  validates :amount_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :status, inclusion: { in: STATUSES }
  validates :receipt_status, inclusion: { in: RECEIPT_STATUSES }
  validates :payment_method, inclusion: { in: PAYMENT_METHODS }

  scope :submitted, -> { where(status: "submitted") }
  scope :approved, -> { where(status: "approved") }
  scope :reimbursable, -> { where(reimbursable: true) }

  def submitted?
    status == "submitted"
  end

  def approved?
    status == "approved"
  end

  def rejected?
    status == "rejected"
  end

  def reimbursed?
    status == "reimbursed"
  end

  def receipt_ready?
    %w[uploaded verified].include?(receipt_status)
  end

  def policy_ready?
    submitted? && reimbursable? && receipt_ready?
  end

  def approval_block_reason
    return "Receipt is missing" unless receipt_ready?
    return "Expense is marked non-reimbursable" unless reimbursable?
    return "Expense is already #{status.humanize.downcase}" unless submitted?

    "Ready"
  end

  def approve!(reviewed_by:)
    update!(
      status: "approved",
      approved_at: Time.current,
      metadata: metadata.to_h.merge(
        "reviewed_by" => reviewed_by,
        "reviewed_at" => Time.current.iso8601
      )
    )
  end

  def reject!(reason:, reviewed_by:)
    update!(
      status: "rejected",
      metadata: metadata.to_h.merge(
        "reviewed_by" => reviewed_by,
        "reviewed_at" => Time.current.iso8601,
        "rejection_reason" => reason
      )
    )
  end

  def mark_reimbursed!(batch_id:)
    update!(
      status: "reimbursed",
      reimbursed_at: Time.current,
      metadata: metadata.to_h.merge(
        "reimbursement_batch_id" => batch_id,
        "reimbursed_at" => Time.current.iso8601
      )
    )
  end
end
