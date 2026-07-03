class WorkersCompClaim < ApplicationRecord
  STATUSES = %w[reported investigating accepted denied closed].freeze
  SEVERITIES = %w[first_aid medical_only lost_time serious].freeze

  belongs_to :employer
  belongs_to :employee
  belongs_to :workers_comp_policy

  validates :incident_on, :reported_on, :status, :severity, :description, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :severity, inclusion: { in: SEVERITIES }
  validates :lost_time_days, :reserve_cents, :paid_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :claim_number, uniqueness: true, allow_blank: true
  validate :employee_belongs_to_employer
  validate :policy_belongs_to_employer

  scope :open, -> { where.not(status: %w[closed denied]) }
  scope :lost_time, -> { where(severity: %w[lost_time serious]) }
  scope :recent_first, -> { order(incident_on: :desc, created_at: :desc) }

  def open?
    !status.in?(%w[closed denied])
  end

  def lost_time?
    severity.in?(%w[lost_time serious]) || lost_time_days.positive?
  end

  def closable?
    open?
  end

  def close!(closed_by:, resolution:)
    update!(
      status: "closed",
      closed_at: Time.current,
      metadata: metadata.to_h.merge(
        "closed_by" => closed_by,
        "closed_at" => Time.current.iso8601,
        "resolution" => resolution
      )
    )
  end

  private

  def employee_belongs_to_employer
    return if employee.blank? || employer.blank? || employee.employer_id == employer_id

    errors.add(:employee, "must belong to claim employer")
  end

  def policy_belongs_to_employer
    return if workers_comp_policy.blank? || employer.blank? || workers_comp_policy.employer_id == employer_id

    errors.add(:workers_comp_policy, "must belong to claim employer")
  end
end
