class CompensationChange < ApplicationRecord
  BASE_PAY_CHANGE_TYPES = %w[base_salary promotion merit_increase market_adjustment].freeze
  ONE_TIME_CHANGE_TYPES = %w[one_time_bonus spot_bonus retention_bonus correction].freeze
  APPROVABLE_STATUSES = %w[draft submitted].freeze

  belongs_to :employer
  belongs_to :employee
  belongs_to :payroll_run, optional: true

  validates :change_type, :status, :reason, :effective_on, presence: true
  validates :current_compensation_cents, :proposed_compensation_cents, :delta_cents, numericality: true
  validate :employee_belongs_to_employer

  scope :recent_first, -> { order(effective_on: :desc, created_at: :desc) }
  scope :reviewable, -> { where(status: %w[draft submitted]) }
  scope :approved, -> { where(status: "approved") }
  scope :not_applied, -> { where(applied_at: nil) }

  def base_pay_change?
    change_type.in?(BASE_PAY_CHANGE_TYPES)
  end

  def one_time_change?
    change_type.in?(ONE_TIME_CHANGE_TYPES)
  end

  def approvable?
    status.in?(APPROVABLE_STATUSES)
  end

  def approved?
    status == "approved"
  end

  def applied?
    status == "applied"
  end

  def rejected?
    status == "rejected"
  end

  private

  def employee_belongs_to_employer
    return if employee.blank? || employer.blank? || employee.employer_id == employer_id

    errors.add(:employee, "must belong to employer")
  end
end
