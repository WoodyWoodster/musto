class EmployerBankAccount < ApplicationRecord
  STATUSES = %w[pending_verification verified blocked].freeze
  ACCOUNT_TYPES = %w[checking savings].freeze
  VERIFICATION_METHODS = %w[microdeposit manual plaid].freeze

  belongs_to :employer

  validates :name, :institution_name, :account_type, :routing_number_last4, :account_last4, :status, :verification_method, presence: true
  validates :account_type, inclusion: { in: ACCOUNT_TYPES }
  validates :status, inclusion: { in: STATUSES }
  validates :verification_method, inclusion: { in: VERIFICATION_METHODS }
  validates :routing_number_last4, :account_last4, length: { is: 4 }

  scope :verified, -> { where(status: "verified") }
  scope :primary_accounts, -> { where(primary_account: true) }

  def verified?
    status == "verified"
  end

  def pending_verification?
    status == "pending_verification"
  end

  def blocked?
    status == "blocked"
  end

  def ready_for_funding?
    verified?
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
