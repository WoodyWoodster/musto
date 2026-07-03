class Enrollment < ApplicationRecord
  belongs_to :employee
  belongs_to :benefit_plan

  has_many :payroll_deductions, dependent: :nullify

  validates :status, :coverage_level, presence: true
  validates :benefit_plan_id, uniqueness: { scope: :employee_id }
  validates :vitable_id, uniqueness: { scope: :employee_id }, allow_blank: true

  scope :accepted, -> { where(status: "accepted") }
  scope :pending, -> { where(status: "pending") }
end
