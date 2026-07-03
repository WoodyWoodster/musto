class Employee < ApplicationRecord
  belongs_to :employer
  belongs_to :department, optional: true
  belongs_to :work_location, optional: true

  has_many :enrollments, dependent: :destroy
  has_many :dependents, dependent: :destroy
  has_many :employee_lifecycle_events, dependent: :destroy
  has_many :payroll_deductions, dependent: :destroy
  has_many :employee_deductions, dependent: :destroy
  has_many :benefit_plans, through: :enrollments
  has_many :onboarding_tasks, dependent: :destroy
  has_many :employee_documents, dependent: :destroy
  has_many :time_off_requests, dependent: :destroy
  has_many :time_entries, dependent: :destroy
  has_many :payroll_adjustments, dependent: :destroy
  has_many :employee_expenses, dependent: :destroy
  has_many :employee_bank_accounts, dependent: :destroy
  has_many :employee_change_requests, dependent: :destroy
  has_many :performance_reviews, dependent: :destroy
  has_many :review_assignments, class_name: "PerformanceReview", foreign_key: :reviewer_id, dependent: :nullify, inverse_of: :reviewer
  has_many :employee_goals, dependent: :destroy
  has_many :training_assignments, dependent: :destroy
  has_many :training_programs, through: :training_assignments
  has_many :pay_statements, dependent: :destroy
  has_many :benefit_invoice_lines, dependent: :destroy
  has_many :open_enrollment_invitations, dependent: :destroy
  has_many :compliance_cases, dependent: :nullify
  has_many :candidate_profiles, class_name: "Candidate", dependent: :nullify

  validates :first_name, :last_name, :email, :employment_status, :pay_type, :onboarding_status, presence: true
  validates :compensation_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :email, uniqueness: { scope: :employer_id }
  validates :vitable_id, uniqueness: { scope: :employer_id }, allow_blank: true

  scope :active, -> { where(employment_status: "active") }
  scope :onboarding, -> { where.not(onboarding_status: "complete") }

  def full_name
    [ first_name, last_name ].join(" ")
  end

  def annual_compensation
    compensation_cents / 100.0
  end
end
