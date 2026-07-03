class PerformanceReview < ApplicationRecord
  STATUSES = %w[draft self_review manager_review calibration complete overdue].freeze

  belongs_to :performance_cycle
  belongs_to :employee
  belongs_to :reviewer, class_name: "Employee", optional: true

  validates :status, :due_on, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :rating, numericality: { greater_than_or_equal_to: 1, less_than_or_equal_to: 5 }, allow_nil: true
  validates :employee_id, uniqueness: { scope: :performance_cycle_id }

  scope :open_review, -> { where(status: %w[draft self_review manager_review calibration overdue]) }
  scope :calibratable, -> { where(status: %w[manager_review calibration]) }

  def draft?
    status == "draft"
  end

  def self_review?
    status == "self_review"
  end

  def manager_review?
    status == "manager_review"
  end

  def calibration?
    status == "calibration"
  end

  def complete?
    status == "complete"
  end

  def overdue?
    status != "complete" && due_on < Date.current
  end

  def calibratable?
    status.in?(%w[manager_review calibration])
  end
end
