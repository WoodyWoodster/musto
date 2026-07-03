class BenefitPlan < ApplicationRecord
  belongs_to :employer

  has_many :enrollments, dependent: :restrict_with_error
  has_many :benefit_invoice_lines, dependent: :restrict_with_error

  validates :name, :category, :status, :contribution_strategy, :eligibility_rule, :review_status, presence: true
  validates :monthly_premium_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :employee_contribution_cents, :employer_contribution_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :plan_year, numericality: { greater_than_or_equal_to: 2020 }, allow_nil: true
  validates :vitable_id, uniqueness: { scope: :employer_id }, allow_blank: true

  scope :available, -> { where(status: "available") }
  scope :published, -> { where(review_status: "published") }
end
