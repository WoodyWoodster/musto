class PayStatement < ApplicationRecord
  STATUSES = %w[generated delivered viewed void].freeze
  DELIVERY_METHODS = %w[employee_portal email manual].freeze

  belongs_to :payroll_run
  belongs_to :employee

  validates :statement_number, :period_start_on, :period_end_on, :pay_date, :status, :delivery_method, presence: true
  validates :statement_number, uniqueness: true
  validates :employee_id, uniqueness: { scope: :payroll_run_id }
  validates :status, inclusion: { in: STATUSES }
  validates :delivery_method, inclusion: { in: DELIVERY_METHODS }
  validates :gross_pay_cents, :adjustment_cents, :deduction_cents, :tax_cents, :net_pay_cents, numericality: true
  validate :period_ends_after_start

  scope :deliverable, -> { where(status: "generated") }
  scope :delivered, -> { where(status: [ "delivered", "viewed" ]) }

  def generated?
    status == "generated"
  end

  def delivered?
    %w[delivered viewed].include?(status)
  end

  def viewed?
    status == "viewed"
  end

  def void?
    status == "void"
  end

  def deliver!(delivered_by:)
    return false if void?

    update!(
      status: "delivered",
      delivered_at: Time.current,
      metadata: metadata.to_h.merge(
        "delivered_by" => delivered_by,
        "delivered_at" => Time.current.iso8601
      )
    )
  end

  def mark_viewed!
    update!(
      status: "viewed",
      viewed_at: Time.current,
      metadata: metadata.to_h.merge("viewed_at" => Time.current.iso8601)
    )
  end

  private

  def period_ends_after_start
    return if period_start_on.blank? || period_end_on.blank? || period_end_on >= period_start_on

    errors.add(:period_end_on, "must be on or after the period start date")
  end
end
