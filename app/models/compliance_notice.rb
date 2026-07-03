class ComplianceNotice < ApplicationRecord
  ACTIONABLE_STATUSES = %w[received in_review response_ready escalated].freeze
  RESOLVED_STATUSES = %w[resolved archived].freeze

  belongs_to :employer
  belongs_to :employee, optional: true

  validates :source, :notice_type, :title, :agency_name, :jurisdiction, :severity, :status, :received_on, :due_on, :response_owner, :response_channel, presence: true
  validates :amount_cents, numericality: { greater_than_or_equal_to: 0 }
  validate :due_on_on_or_after_received_on
  validate :employee_belongs_to_employer

  scope :open, -> { where.not(status: RESOLVED_STATUSES) }
  scope :actionable, -> { where(status: ACTIONABLE_STATUSES) }
  scope :due_first, -> { order(due_on: :asc, created_at: :asc) }
  scope :urgent, -> { open.where(severity: %w[critical high]) }

  def open?
    status.in?(ACTIONABLE_STATUSES)
  end

  def acknowledged?
    acknowledged_at.present?
  end

  def response_ready?
    status == "response_ready"
  end

  def resolved?
    status == "resolved"
  end

  def overdue?
    due_on.present? && due_on < Date.current && open?
  end

  def due_soon?
    due_on.present? && due_on <= 10.days.from_now.to_date && open?
  end

  private

  def due_on_on_or_after_received_on
    return if received_on.blank? || due_on.blank? || due_on >= received_on

    errors.add(:due_on, "must be on or after received on")
  end

  def employee_belongs_to_employer
    return if employee.blank? || employer.blank? || employee.employer_id == employer_id

    errors.add(:employee, "must belong to employer")
  end
end
