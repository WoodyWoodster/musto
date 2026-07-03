class OpenEnrollmentInvitation < ApplicationRecord
  STATUSES = %w[not_sent sent opened reminded completed waived blocked].freeze

  belongs_to :open_enrollment_campaign
  belongs_to :employee

  validates :status, :due_on, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :employee_id, uniqueness: { scope: :open_enrollment_campaign_id }

  scope :actionable, -> { where(status: [ "not_sent", "sent", "opened", "reminded", "blocked" ]) }
  scope :remindable, -> { where(status: [ "sent", "opened", "reminded", "blocked" ]) }

  def sent?
    status.in?([ "sent", "opened", "reminded", "completed", "waived", "blocked" ])
  end

  def completed?
    status == "completed"
  end

  def waived?
    status == "waived"
  end

  def remindable?
    status.in?([ "sent", "opened", "reminded", "blocked" ])
  end

  def overdue?
    !completed? && !waived? && due_on < Date.current
  end
end
