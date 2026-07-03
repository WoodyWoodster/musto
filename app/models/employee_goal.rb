class EmployeeGoal < ApplicationRecord
  STATUSES = %w[on_track at_risk complete paused].freeze

  belongs_to :employee
  belongs_to :performance_cycle, optional: true

  validates :title, :status, :due_on, :owner, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :progress_percent, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }

  scope :open_goals, -> { where.not(status: "complete") }
  scope :at_risk, -> { where(status: "at_risk") }

  def complete?
    status == "complete"
  end

  def at_risk?
    status == "at_risk"
  end

  def complete!(reviewed_by:)
    update!(
      status: "complete",
      progress_percent: 100,
      completed_at: Time.current,
      metadata: metadata.to_h.merge(
        "completed_by" => reviewed_by,
        "completed_at" => Time.current.iso8601
      )
    )
  end
end
