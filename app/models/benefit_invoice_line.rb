class BenefitInvoiceLine < ApplicationRecord
  belongs_to :benefit_invoice
  belongs_to :employee
  belongs_to :benefit_plan
  belongs_to :enrollment, optional: true

  validates :coverage_level, :status, presence: true
  validates :amount_cents, :expected_premium_cents, :expected_payroll_deduction_cents, :employee_contribution_cents, :employer_contribution_cents, numericality: { greater_than_or_equal_to: 0 }

  scope :with_variance, -> { where.not(variance_cents: 0) }
  scope :matched, -> { where(status: "matched") }

  def matched?
    status == "matched"
  end

  def blocked?
    status.in?([ "variance", "missing_deduction", "needs_review" ])
  end
end
