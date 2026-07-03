class PayrollSchedule < ApplicationRecord
  CADENCES = %w[weekly biweekly semimonthly monthly].freeze
  STATUSES = %w[active paused archived].freeze

  belongs_to :employer

  has_many :payroll_approval_steps, dependent: :nullify

  validates :name, :cadence, :status, :period_anchor_on, :next_period_start_on, :next_period_end_on, :next_pay_date, :approval_deadline_at, :funding_deadline_at, :timezone, presence: true
  validates :cadence, inclusion: { in: CADENCES }
  validates :status, inclusion: { in: STATUSES }
  validates :name, uniqueness: { scope: :employer_id }
  validate :period_ends_after_start
  validate :funding_after_approval

  scope :active, -> { where(status: "active") }
  scope :upcoming_first, -> { order(next_pay_date: :asc, created_at: :asc) }

  def active?
    status == "active"
  end

  def paused?
    status == "paused"
  end

  def days_until_payday
    (next_pay_date - Date.current).to_i
  end

  private

  def period_ends_after_start
    return if next_period_start_on.blank? || next_period_end_on.blank? || next_period_end_on >= next_period_start_on

    errors.add(:next_period_end_on, "must be on or after the next period start date")
  end

  def funding_after_approval
    return if approval_deadline_at.blank? || funding_deadline_at.blank? || funding_deadline_at >= approval_deadline_at

    errors.add(:funding_deadline_at, "must be after the approval deadline")
  end
end
