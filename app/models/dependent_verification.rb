class DependentVerification < ApplicationRecord
  belongs_to :dependent
  belongs_to :employee_document, optional: true

  validates :verification_type, :status, :requested_on, :due_on, presence: true
  validate :due_on_on_or_after_requested_on

  scope :recent_first, -> { order(due_on: :asc, created_at: :desc) }
  scope :open, -> { where(status: [ "requested", "needs_review" ]) }
  scope :approved, -> { where(status: "approved") }

  def approved?
    status == "approved"
  end

  def rejected?
    status == "rejected"
  end

  def open?
    status.in?([ "requested", "needs_review" ])
  end

  private

  def due_on_on_or_after_requested_on
    return if requested_on.blank? || due_on.blank? || due_on >= requested_on

    errors.add(:due_on, "must be on or after requested on")
  end
end
