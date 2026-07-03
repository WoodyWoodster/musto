class PerformanceCycle < ApplicationRecord
  STATUSES = %w[draft active calibration closed archived].freeze
  REVIEW_TYPES = %w[quarterly annual probation pulse].freeze

  belongs_to :employer

  has_many :performance_reviews, dependent: :destroy
  has_many :employee_goals, dependent: :nullify

  validates :name, :status, :review_type, :period_start_on, :period_end_on, :due_on, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :review_type, inclusion: { in: REVIEW_TYPES }
  validate :period_order

  scope :current_first, -> { order(status: :asc, period_end_on: :desc, created_at: :desc) }

  def draft?
    status == "draft"
  end

  def active?
    status == "active"
  end

  def calibration?
    status == "calibration"
  end

  def closed?
    status == "closed"
  end

  def launch!(requested_by:)
    update!(
      status: "active",
      launched_at: Time.current,
      metadata: metadata.to_h.merge(
        "launched_by" => requested_by,
        "launched_at" => Time.current.iso8601
      )
    )
  end

  private

  def period_order
    return if period_start_on.blank? || period_end_on.blank? || period_end_on >= period_start_on

    errors.add(:period_end_on, "must be on or after the period start")
  end
end
