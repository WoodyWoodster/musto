class Dependent < ApplicationRecord
  belongs_to :employee
  has_many :dependent_verifications, dependent: :destroy

  validates :first_name, :last_name, :relationship, :enrollment_status, :eligibility_status, presence: true
  validates :vitable_id, uniqueness: { scope: :employee_id }, allow_blank: true

  scope :eligible, -> { where(enrollment_status: "enrolled", eligibility_status: "eligible") }
  scope :needs_review, -> { where.not(eligibility_status: "eligible") }

  def full_name
    [ first_name, last_name ].join(" ")
  end

  def enrolled?
    enrollment_status == "enrolled"
  end

  def eligible?
    enrolled? && eligibility_status == "eligible"
  end
end
