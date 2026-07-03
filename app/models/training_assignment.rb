class TrainingAssignment < ApplicationRecord
  STATUSES = %w[assigned in_progress complete overdue waived].freeze

  belongs_to :training_program
  belongs_to :employee

  validates :status, :due_on, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :score, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_nil: true
  validates :employee_id, uniqueness: { scope: :training_program_id }

  scope :open_assignment, -> { where(status: %w[assigned in_progress overdue]) }
  scope :certificate_ready, -> { where(status: "complete").where.not(certificate_id: [ nil, "" ]) }

  def assigned?
    status == "assigned"
  end

  def in_progress?
    status == "in_progress"
  end

  def complete?
    status == "complete"
  end

  def waived?
    status == "waived"
  end

  def overdue?
    !complete? && !waived? && due_on < Date.current
  end

  def completable?
    !complete? && !waived?
  end

  def complete!(completed_by:, score: nil)
    completed_score = score || self.score || 100
    update!(
      status: "complete",
      completed_at: Time.current,
      score: completed_score,
      certificate_id: certificate_id.presence || "TRN-#{training_program_id}-#{employee_id}-#{Time.current.to_i}",
      metadata: metadata.to_h.merge(
        "completed_by" => completed_by,
        "completed_at" => Time.current.iso8601
      )
    )
  end
end
