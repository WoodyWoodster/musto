class EmployeeDeduction < ApplicationRecord
  STATUSES = %w[pending active paused blocked closed].freeze
  DEDUCTION_TYPES = %w[child_support tax_levy creditor_garnishment benefit retirement loan_repayment equipment other].freeze
  CALCULATION_METHODS = %w[fixed_amount percent_gross remaining_balance court_order].freeze

  belongs_to :employer
  belongs_to :employee

  validates :title, :deduction_type, :status, :calculation_method, :starts_on, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :deduction_type, inclusion: { in: DEDUCTION_TYPES }
  validates :calculation_method, inclusion: { in: CALCULATION_METHODS }
  validates :amount_cents, :priority, numericality: { greater_than_or_equal_to: 0 }
  validates :percent_basis_points, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 10_000 }, allow_nil: true
  validates :max_per_paycheck_cents, :current_balance_cents, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validate :employee_belongs_to_employer
  validate :calculation_has_value

  scope :current_first, -> { order(status: :asc, priority: :asc, starts_on: :desc, created_at: :desc) }
  scope :active_or_pending, -> { where(status: %w[active pending blocked]) }
  scope :ready_for_payroll, -> { where(status: "active") }

  def pending?
    status == "pending"
  end

  def active?
    status == "active"
  end

  def paused?
    status == "paused"
  end

  def blocked?
    status == "blocked"
  end

  def closed?
    status == "closed"
  end

  def garnishment?
    deduction_type.in?(%w[child_support tax_levy creditor_garnishment])
  end

  def approvable?
    pending? || blocked?
  end

  def pausable?
    active?
  end

  def ready_for_payroll?(pay_date: Date.current)
    active? && starts_on <= pay_date && (ends_on.blank? || ends_on >= pay_date) && positive_remaining_balance?
  end

  def estimated_amount_for(gross_cents, pay_date: Date.current)
    return 0 unless ready_for_payroll?(pay_date:)

    amount = if calculation_method == "percent_gross"
      ((gross_cents.to_i * percent_basis_points.to_i) / 10_000.0).round
    elsif calculation_method == "remaining_balance"
      [ amount_cents, current_balance_cents.to_i ].select(&:positive?).min || 0
    else
      amount_cents
    end

    amount = [ amount, max_per_paycheck_cents ].min if max_per_paycheck_cents.to_i.positive?
    amount = [ amount, current_balance_cents ].min if current_balance_cents.to_i.positive?
    [ amount, 0 ].max
  end

  def activate!(approved_by:)
    update!(
      status: "active",
      approved_at: Time.current,
      paused_at: nil,
      metadata: metadata.to_h.merge(
        "approved_by" => approved_by,
        "approved_at" => Time.current.iso8601
      )
    )
  end

  def pause!(paused_by:, reason:)
    update!(
      status: "paused",
      paused_at: Time.current,
      metadata: metadata.to_h.merge(
        "paused_by" => paused_by,
        "paused_at" => Time.current.iso8601,
        "paused_reason" => reason
      )
    )
  end

  private

  def employee_belongs_to_employer
    return if employee.blank? || employer.blank? || employee.employer_id == employer_id

    errors.add(:employee, "must belong to the deduction employer")
  end

  def calculation_has_value
    return if calculation_method == "percent_gross" && percent_basis_points.to_i.positive?
    return if calculation_method != "percent_gross" && amount_cents.to_i.positive?

    errors.add(:base, "Deduction calculation must include an amount or percent")
  end

  def positive_remaining_balance?
    current_balance_cents.nil? || current_balance_cents.positive?
  end
end
