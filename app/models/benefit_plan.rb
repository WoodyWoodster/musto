class BenefitPlan < ApplicationRecord
  belongs_to :employer

  has_many :enrollments, dependent: :restrict_with_error

  validates :name, :category, :status, presence: true
  validates :monthly_premium_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :vitable_id, uniqueness: { scope: :employer_id }, allow_blank: true

  scope :available, -> { where(status: "available") }
end
