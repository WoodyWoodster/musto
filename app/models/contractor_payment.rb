class ContractorPayment < ApplicationRecord
  belongs_to :contractor

  validates :work_period_start_on, :work_period_end_on, :pay_date, :description, :status, :payment_method, presence: true
  validates :amount_cents, numericality: { greater_than_or_equal_to: 0 }
  validate :work_period_ends_after_start

  scope :approved, -> { where(status: "approved") }
  scope :pending_approval, -> { where(status: "draft") }

  def draft?
    status == "draft"
  end

  def approved?
    status == "approved"
  end

  def scheduled?
    status == "scheduled"
  end

  def paid?
    status == "paid"
  end

  def payable?
    approved? || scheduled?
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

  def block!(reason:)
    update!(
      status: "blocked",
      metadata: metadata.to_h.merge(
        "blocked_reason" => reason,
        "blocked_at" => Time.current.iso8601
      )
    )
  end

  private

  def work_period_ends_after_start
    return if work_period_start_on.blank? || work_period_end_on.blank? || work_period_end_on >= work_period_start_on

    errors.add(:work_period_end_on, "must be on or after the period start")
  end
end
