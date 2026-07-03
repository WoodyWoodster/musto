class Employer < ApplicationRecord
  belongs_to :organization

  has_many :employees, dependent: :destroy
  has_many :job_openings, dependent: :destroy
  has_many :candidates, through: :job_openings
  has_many :contractors, dependent: :destroy
  has_many :departments, dependent: :destroy
  has_many :work_locations, dependent: :destroy
  has_many :benefit_plans, dependent: :destroy
  has_many :benefit_invoices, dependent: :destroy
  has_many :open_enrollment_campaigns, dependent: :destroy
  has_many :performance_cycles, dependent: :destroy
  has_many :performance_reviews, through: :performance_cycles
  has_many :training_programs, dependent: :destroy
  has_many :training_assignments, through: :training_programs
  has_many :payroll_schedules, dependent: :destroy
  has_many :payroll_runs, dependent: :destroy
  has_many :employer_bank_accounts, dependent: :destroy
  has_many :enrollments, through: :employees
  has_many :time_off_policies, dependent: :destroy
  has_many :time_off_requests, through: :employees
  has_many :onboarding_tasks, through: :employees
  has_many :employee_documents, through: :employees
  has_many :employee_expenses, through: :employees
  has_many :employee_bank_accounts, through: :employees
  has_many :employee_change_requests, through: :employees
  has_many :employee_goals, through: :employees
  has_many :compliance_cases, dependent: :destroy

  validates :name, :status, presence: true
  validates :vitable_id, uniqueness: { scope: :organization_id }, allow_blank: true

  scope :onboarded, -> { where.not(onboarded_at: nil) }
  scope :for_status, ->(status) { where(status:) if status.present? }

  def payroll_ready_employee_count
    employees.active.where.not(compensation_cents: 0).count
  end
end
