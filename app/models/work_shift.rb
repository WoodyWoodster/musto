class WorkShift < ApplicationRecord
  STATUSES = %w[draft published completed missed canceled].freeze

  belongs_to :employer
  belongs_to :employee, optional: true
  belongs_to :department, optional: true
  belongs_to :work_location, optional: true

  has_many :shift_swap_requests, dependent: :destroy

  validates :role, :status, :starts_at, :ends_at, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :break_minutes, :hourly_rate_cents, numericality: { greater_than_or_equal_to: 0 }
  validate :ends_after_start
  validate :employee_belongs_to_employer

  scope :chronological, -> { order(starts_at: :asc, created_at: :desc) }
  scope :current_window, -> { where(starts_at: Date.current.beginning_of_week.beginning_of_day..(Date.current.end_of_week + 14.days).end_of_day) }

  def draft?
    status == "draft"
  end

  def published?
    status == "published"
  end

  def completed?
    status == "completed"
  end

  def canceled?
    status == "canceled"
  end

  def missed?
    status == "missed"
  end

  def open_shift?
    employee_id.blank?
  end

  def payable?
    employee_id.present? && status.in?(%w[published completed]) && hourly_rate_cents.positive? && net_minutes.positive?
  end

  def duration_minutes
    return 0 if starts_at.blank? || ends_at.blank?

    ((ends_at - starts_at) / 60).round
  end

  def net_minutes
    [ duration_minutes - break_minutes, 0 ].max
  end

  def labor_cost_cents
    ((net_minutes / 60.0) * hourly_rate_cents).round
  end

  def publish!(published_by:)
    update!(
      status: "published",
      published_at: Time.current,
      metadata: metadata.to_h.merge(
        "published_by" => published_by,
        "published_at" => Time.current.iso8601
      )
    )
  end

  private

  def ends_after_start
    return if starts_at.blank? || ends_at.blank? || ends_at > starts_at

    errors.add(:ends_at, "must be after the shift start")
  end

  def employee_belongs_to_employer
    return if employee.blank? || employer.blank? || employee.employer_id == employer_id

    errors.add(:employee, "must belong to the shift employer")
  end
end
