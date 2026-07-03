class PayrollRun < ApplicationRecord
  belongs_to :employer

  has_many :payroll_deductions, dependent: :destroy
  has_many :payroll_adjustments, dependent: :destroy

  validates :period_start_on, :period_end_on, :pay_date, :status, presence: true
  validates :gross_pay_cents, numericality: { greater_than_or_equal_to: 0 }
  validate :period_ends_after_start

  def total_deductions_cents
    payroll_deductions.sum(:amount_cents)
  end

  def total_adjustments_cents
    payroll_adjustments.sum(:amount_cents)
  end

  def estimated_net_pay_cents
    gross_pay_cents + total_adjustments_cents - total_deductions_cents - estimated_tax_cents
  end

  def estimated_tax_cents
    (gross_pay_cents * 0.18).round
  end

  private

  def period_ends_after_start
    return if period_start_on.blank? || period_end_on.blank? || period_end_on >= period_start_on

    errors.add(:period_end_on, "must be on or after the period start date")
  end
end
