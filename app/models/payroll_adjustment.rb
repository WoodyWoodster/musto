class PayrollAdjustment < ApplicationRecord
  belongs_to :payroll_run
  belongs_to :employee

  validates :adjustment_type, :description, presence: true
  validates :amount_cents, numericality: true
end
