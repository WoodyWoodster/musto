class TimeOffRequest < ApplicationRecord
  belongs_to :employee
  belongs_to :time_off_policy

  validates :starts_on, :ends_on, :hours, :status, presence: true
  validates :hours, numericality: { greater_than: 0 }
  validate :ends_on_after_starts_on

  scope :pending, -> { where(status: "requested") }
  scope :upcoming, -> { where(starts_on: Date.current..) }

  private

  def ends_on_after_starts_on
    return if starts_on.blank? || ends_on.blank? || ends_on >= starts_on

    errors.add(:ends_on, "must be on or after the start date")
  end
end
