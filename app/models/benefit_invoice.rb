class BenefitInvoice < ApplicationRecord
  belongs_to :employer

  has_many :benefit_invoice_lines, dependent: :destroy

  validates :invoice_number, :carrier, :period_start_on, :period_end_on, :due_on, :status, presence: true
  validates :invoice_number, uniqueness: { scope: :employer_id }
  validates :total_premium_cents, :employee_contribution_cents, :employer_contribution_cents, numericality: { greater_than_or_equal_to: 0 }

  scope :open, -> { where.not(status: [ "paid" ]) }
  scope :recent_first, -> { order(period_end_on: :desc, due_on: :asc) }

  def approved?
    status == "approved"
  end

  def paid?
    status == "paid"
  end

  def needs_review?
    status == "needs_review" || variance_cents != 0
  end

  def approve!(reviewed_by:)
    update!(
      status: "approved",
      approved_at: Time.current,
      metadata: metadata.to_h.merge(
        "approved_by" => reviewed_by,
        "approved_at" => Time.current.iso8601
      )
    )
  end
end
