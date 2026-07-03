class PayrollDeduction < ApplicationRecord
  belongs_to :payroll_run
  belongs_to :employee
  belongs_to :enrollment, optional: true

  validates :amount_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :code, :status, presence: true
  validates :vitable_id, uniqueness: true, allow_blank: true
end
