class YearEndTaxForm < ApplicationRecord
  FORM_TYPES = %w[w2 1099_nec].freeze
  STATUSES = %w[draft ready filed delivered accepted correction_needed void].freeze
  DELIVERY_METHODS = %w[employee_portal contractor_portal email mail manual].freeze
  CONSENT_STATUSES = %w[not_requested requested electronic_consented paper_required].freeze
  CORRECTION_STATUSES = %w[none pending corrected voided].freeze

  belongs_to :employer
  belongs_to :employee, optional: true
  belongs_to :contractor, optional: true

  validates :tax_year, :form_type, :recipient_name, :recipient_email, :jurisdiction, :status, :delivery_method, :consent_status, :correction_status, :due_on, presence: true
  validates :form_type, inclusion: { in: FORM_TYPES }
  validates :status, inclusion: { in: STATUSES }
  validates :delivery_method, inclusion: { in: DELIVERY_METHODS }
  validates :consent_status, inclusion: { in: CONSENT_STATUSES }
  validates :correction_status, inclusion: { in: CORRECTION_STATUSES }
  validates :gross_wages_cents, :federal_withholding_cents, :state_withholding_cents, :benefit_reportable_cents, :contractor_payment_cents, numericality: { greater_than_or_equal_to: 0 }
  validate :single_recipient
  validate :recipient_belongs_to_employer
  validate :form_type_matches_recipient

  scope :for_year, ->(year) { where(tax_year: year) }
  scope :ready_for_delivery, -> { where(status: %w[ready filed]) }
  scope :open, -> { where.not(status: %w[accepted void]) }
  scope :due_first, -> { order(tax_year: :desc, due_on: :asc, created_at: :asc) }

  def employee_form?
    form_type == "w2"
  end

  def contractor_form?
    form_type == "1099_nec"
  end

  def deliverable?
    status.in?(%w[ready filed])
  end

  def delivered?
    status.in?(%w[delivered accepted])
  end

  def accepted?
    status == "accepted"
  end

  def correction_needed?
    status == "correction_needed" || correction_status.in?(%w[pending corrected])
  end

  private

  def single_recipient
    return if employee_id.present? ^ contractor_id.present?

    errors.add(:base, "must have exactly one employee or contractor recipient")
  end

  def recipient_belongs_to_employer
    return if employer.blank?

    errors.add(:employee, "must belong to employer") if employee.present? && employee.employer_id != employer_id
    errors.add(:contractor, "must belong to employer") if contractor.present? && contractor.employer_id != employer_id
  end

  def form_type_matches_recipient
    errors.add(:form_type, "must be w2 for employees") if employee_id.present? && form_type != "w2"
    errors.add(:form_type, "must be 1099_nec for contractors") if contractor_id.present? && form_type != "1099_nec"
  end
end
