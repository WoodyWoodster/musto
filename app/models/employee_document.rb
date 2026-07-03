class EmployeeDocument < ApplicationRecord
  belongs_to :employee

  validates :title, :document_type, :status, presence: true

  scope :attention_needed, -> { where(status: [ "pending", "requested", "expired" ]) }
  scope :expiring_soon, -> { where(expires_on: Date.current..60.days.from_now.to_date) }
  scope :complete, -> { where(status: "complete") }
  scope :requested, -> { where(status: "requested") }

  def expired?
    expires_on.present? && expires_on < Date.current
  end

  def complete?
    status == "complete"
  end

  def requested?
    status == "requested"
  end

  def pending?
    status == "pending"
  end

  def attention_needed?
    !complete? || expired? || expiring_soon?
  end

  def expiring_soon?
    expires_on.present? && expires_on <= 60.days.from_now.to_date && !expired?
  end
end
