class JobOpening < ApplicationRecord
  STATUSES = %w[draft open paused closed archived].freeze
  EMPLOYMENT_TYPES = %w[full_time part_time temporary contractor internship].freeze

  belongs_to :employer
  belongs_to :department, optional: true
  belongs_to :work_location, optional: true

  has_many :candidates, dependent: :destroy

  validates :title, :code, :status, :employment_type, presence: true
  validates :code, uniqueness: { scope: :employer_id }
  validates :status, inclusion: { in: STATUSES }
  validates :employment_type, inclusion: { in: EMPLOYMENT_TYPES }
  validates :headcount, numericality: { greater_than: 0 }
  validates :compensation_min_cents, :compensation_max_cents, numericality: { greater_than_or_equal_to: 0 }
  validate :compensation_range_order

  scope :open_roles, -> { where(status: "open") }
  scope :current_first, -> { order(status: :asc, target_start_on: :asc, created_at: :desc) }

  def open?
    status == "open"
  end

  private

  def compensation_range_order
    return if compensation_min_cents.blank? || compensation_max_cents.blank? || compensation_max_cents >= compensation_min_cents

    errors.add(:compensation_max_cents, "must be greater than or equal to the minimum")
  end
end
