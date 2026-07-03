class PayrollApprovalStep < ApplicationRecord
  STATUSES = %w[open in_progress blocked completed skipped].freeze
  SEVERITIES = %w[low medium high critical].freeze

  belongs_to :payroll_run
  belongs_to :payroll_schedule, optional: true

  validates :key, :title, :owner, :status, :severity, :position, :due_at, presence: true
  validates :key, uniqueness: { scope: :payroll_run_id }
  validates :status, inclusion: { in: STATUSES }
  validates :severity, inclusion: { in: SEVERITIES }

  scope :ordered, -> { order(:position, :due_at, :created_at) }
  scope :incomplete, -> { where.not(status: [ "completed", "skipped" ]) }

  def completed?
    status == "completed"
  end

  def blocked?
    status == "blocked"
  end

  def completable?
    !completed? && !blocked?
  end

  def overdue?
    !completed? && due_at < Time.current
  end

  def complete!(completed_by:)
    update!(
      status: "completed",
      completed_at: Time.current,
      completed_by:,
      metadata: metadata.to_h.merge(
        "completed_by" => completed_by,
        "completed_at" => Time.current.iso8601
      )
    )
  end
end
