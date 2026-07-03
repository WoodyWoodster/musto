class WorkersCompPolicy < ApplicationRecord
  STATUSES = %w[draft active renewal_due expired canceled].freeze

  belongs_to :employer
  has_many :workers_comp_claims, dependent: :destroy

  validates :carrier, :policy_number, :status, :coverage_start_on, :coverage_end_on, :renewal_due_on, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :payroll_basis_cents, :manual_premium_cents, :deposit_premium_cents, :rate_basis_points, numericality: { greater_than_or_equal_to: 0 }
  validates :policy_number, uniqueness: { scope: :employer_id }
  validate :coverage_ends_after_start

  scope :current_first, -> { order(status: :asc, coverage_end_on: :desc, created_at: :desc) }
  scope :active, -> { where(status: "active") }

  def active?
    status == "active"
  end

  def renewal_due?
    status == "renewal_due" || renewal_due_on <= 45.days.from_now.to_date
  end

  def expired?
    coverage_end_on < Date.current || status == "expired"
  end

  def coverage_active?
    active? && coverage_start_on <= Date.current && coverage_end_on >= Date.current
  end

  private

  def coverage_ends_after_start
    return if coverage_start_on.blank? || coverage_end_on.blank? || coverage_end_on >= coverage_start_on

    errors.add(:coverage_end_on, "must be on or after the coverage start date")
  end
end
