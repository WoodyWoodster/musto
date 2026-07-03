class EmployeeDocument < ApplicationRecord
  belongs_to :employee

  validates :title, :document_type, :status, presence: true

  scope :attention_needed, -> { where(status: [ "pending", "expired" ]) }
  scope :expiring_soon, -> { where(expires_on: Date.current..60.days.from_now.to_date) }

  def expired?
    expires_on.present? && expires_on < Date.current
  end
end
