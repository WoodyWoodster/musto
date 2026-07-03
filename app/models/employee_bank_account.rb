class EmployeeBankAccount < ApplicationRecord
  STATUSES = %w[pending_verification prenote_sent verified blocked].freeze
  ACCOUNT_TYPES = %w[checking savings pay_card].freeze
  ALLOCATION_TYPES = %w[remainder percent fixed].freeze
  VERIFICATION_METHODS = %w[prenote microdeposit manual].freeze

  belongs_to :employee

  validates :nickname, :institution_name, :account_type, :routing_number_last4, :account_last4, :allocation_type, :status, :verification_method, presence: true
  validates :account_type, inclusion: { in: ACCOUNT_TYPES }
  validates :allocation_type, inclusion: { in: ALLOCATION_TYPES }
  validates :status, inclusion: { in: STATUSES }
  validates :verification_method, inclusion: { in: VERIFICATION_METHODS }
  validates :routing_number_last4, :account_last4, length: { is: 4 }
  validates :allocation_value, numericality: { greater_than_or_equal_to: 0 }

  scope :verified, -> { where(status: "verified") }
  scope :pending_review, -> { where(status: [ "pending_verification", "prenote_sent" ]) }
  scope :primary_accounts, -> { where(primary_account: true) }

  def pending_verification?
    status == "pending_verification"
  end

  def prenote_sent?
    status == "prenote_sent"
  end

  def verified?
    status == "verified"
  end

  def blocked?
    status == "blocked"
  end

  def ready_for_deposit?
    verified?
  end

  def readiness_status
    return "ready" if ready_for_deposit?
    return "blocked" if blocked?

    "needs_review"
  end

  def verify!(reviewed_by:)
    update!(
      status: "verified",
      verified_at: Time.current,
      metadata: metadata.to_h.merge(
        "verified_by" => reviewed_by,
        "verified_at" => Time.current.iso8601
      )
    )
  end
end
