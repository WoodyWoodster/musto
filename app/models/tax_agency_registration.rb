class TaxAgencyRegistration < ApplicationRecord
  SUBMITTABLE_STATUSES = %w[draft needs_review blocked].freeze
  ACTIVE_STATUSES = %w[draft needs_review blocked submitted registered].freeze

  belongs_to :employer
  belongs_to :work_location, optional: true

  validates :agency_name, :jurisdiction, :registration_type, :deposit_schedule, :status, :risk_level, :due_on, :owner, presence: true
  validate :work_location_belongs_to_employer
  validate :confirmation_requires_submission

  scope :active, -> { where(status: ACTIVE_STATUSES) }
  scope :open, -> { where.not(status: %w[registered archived]) }
  scope :due_first, -> { order(due_on: :asc, created_at: :asc) }
  scope :reviewable, -> { where(status: %w[draft needs_review blocked]) }

  def submitted?
    status == "submitted"
  end

  def registered?
    status == "registered"
  end

  def blocked?
    status == "blocked"
  end

  def needs_review?
    status == "needs_review"
  end

  def overdue?
    due_on.present? && due_on < Date.current && !registered?
  end

  def due_soon?
    due_on.present? && due_on <= 14.days.from_now.to_date && !registered?
  end

  def submittable?
    status.in?(SUBMITTABLE_STATUSES)
  end

  private

  def work_location_belongs_to_employer
    return if work_location.blank? || employer.blank? || work_location.employer_id == employer_id

    errors.add(:work_location, "must belong to employer")
  end

  def confirmation_requires_submission
    return if confirmation_number.blank? || submitted_at.present? || confirmed_at.present?

    errors.add(:confirmation_number, "requires submitted or confirmed timing")
  end
end
