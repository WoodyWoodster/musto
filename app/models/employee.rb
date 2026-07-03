class Employee < ApplicationRecord
  belongs_to :employer
  belongs_to :department, optional: true
  belongs_to :work_location, optional: true

  has_many :enrollments, dependent: :destroy
  has_many :payroll_deductions, dependent: :destroy
  has_many :benefit_plans, through: :enrollments
  has_many :onboarding_tasks, dependent: :destroy
  has_many :employee_documents, dependent: :destroy
  has_many :time_off_requests, dependent: :destroy
  has_many :payroll_adjustments, dependent: :destroy
  has_many :compliance_cases, dependent: :nullify

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
