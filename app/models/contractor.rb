class Contractor < ApplicationRecord
  belongs_to :employer

  has_many :contractor_payments, dependent: :destroy

  validates :first_name, :last_name, :email, :contractor_type, :status, :tax_form_status, :payment_method_status, presence: true
  validates :hourly_rate_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :email, uniqueness: { scope: :employer_id }

  scope :active, -> { where(status: "active") }
  scope :onboarding, -> { where(status: "onboarding") }

  def full_name
    [ first_name, last_name ].join(" ")
  end

  def display_name
    business_name.presence || full_name
  end

  def ready_for_payment?
    status == "active" && tax_form_status == "complete" && payment_method_status == "verified"
  end
end
