class TimeEntry < ApplicationRecord
  belongs_to :employee

  validates :work_date, :clock_in_at, :clock_out_at, :source, :status, presence: true
  validates :break_minutes, numericality: { greater_than_or_equal_to: 0 }
  validate :clock_out_after_clock_in
  validate :break_shorter_than_shift

  scope :pending_review, -> { where(status: "submitted") }
  scope :approved, -> { where(status: "approved") }
  scope :for_period, ->(start_on, end_on) { where(work_date: start_on..end_on) }

  def submitted?
    status == "submitted"
  end

  def approved?
    status == "approved"
  end

  def rejected?
    status == "rejected"
  end

  def duration_minutes
    return 0 if clock_in_at.blank? || clock_out_at.blank?

    (((clock_out_at - clock_in_at) / 60).round - break_minutes).clamp(0, Float::INFINITY)
  end

  def payable_hours
    duration_minutes / 60.0
  end

  def review!(decision:, reviewed_by:)
    update!(
      status: decision,
      approved_at: decision == "approved" ? Time.current : approved_at,
      reviewed_at: Time.current,
      metadata: metadata.to_h.merge(
        "reviewed_by" => reviewed_by,
        "review_decision" => decision,
        "reviewed_at" => Time.current.iso8601
      )
    )
  end

  private

  def clock_out_after_clock_in
    return if clock_in_at.blank? || clock_out_at.blank? || clock_out_at > clock_in_at

    errors.add(:clock_out_at, "must be after clock in")
  end

  def break_shorter_than_shift
    return if clock_in_at.blank? || clock_out_at.blank?

    shift_minutes = ((clock_out_at - clock_in_at) / 60).round
    errors.add(:break_minutes, "must be shorter than the shift") if break_minutes >= shift_minutes
  end
end
