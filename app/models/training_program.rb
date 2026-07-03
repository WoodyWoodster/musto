class TrainingProgram < ApplicationRecord
  STATUSES = %w[draft active closed archived].freeze
  CATEGORIES = %w[compliance security harassment safety benefits payroll].freeze
  CADENCES = %w[one_time quarterly annual biennial].freeze

  belongs_to :employer

  has_many :training_assignments, dependent: :destroy

  validates :title, :category, :audience, :cadence, :status, :due_on, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :category, inclusion: { in: CATEGORIES }
  validates :cadence, inclusion: { in: CADENCES }
  validates :required_count, :completed_count, :overdue_count, numericality: { greater_than_or_equal_to: 0 }

  scope :current_first, -> { order(status: :asc, due_on: :asc, created_at: :desc) }
  scope :active_or_draft, -> { where(status: %w[active draft]) }

  def draft?
    status == "draft"
  end

  def active?
    status == "active"
  end

  def closed?
    status == "closed"
  end

  def launch!(requested_by:)
    update!(
      status: "active",
      launch_on: launch_on || Date.current,
      launched_at: Time.current,
      metadata: metadata.to_h.merge(
        "launched_by" => requested_by,
        "launched_at" => Time.current.iso8601
      )
    )
  end

  def refresh_counts!
    assignments = training_assignments.to_a
    update!(
      required_count: assignments.count,
      completed_count: assignments.count(&:complete?),
      overdue_count: assignments.count(&:overdue?)
    )
  end
end
