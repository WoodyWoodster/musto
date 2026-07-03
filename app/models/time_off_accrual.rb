class TimeOffAccrual < ApplicationRecord
  belongs_to :employee
  belongs_to :time_off_policy
  belongs_to :payroll_run, optional: true

  validates :accrual_type, :hours, :period_start_on, :period_end_on, :effective_on, :source, :status, presence: true
  validates :hours, numericality: { other_than: 0 }
  validate :period_end_on_after_period_start_on

  scope :recent_first, -> { order(effective_on: :desc, created_at: :desc) }
  scope :approved, -> { where(status: "approved") }
  scope :pending, -> { where(status: "pending") }

  def credit?
    hours.positive?
  end

  def debit?
    hours.negative?
  end

  private

  def period_end_on_after_period_start_on
    return if period_start_on.blank? || period_end_on.blank? || period_end_on >= period_start_on

    errors.add(:period_end_on, "must be on or after period start")
  end
end
