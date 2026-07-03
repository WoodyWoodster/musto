class ComplianceCase < ApplicationRecord
  belongs_to :employer
  belongs_to :employee, optional: true

  validates :kind, :severity, :status, presence: true

  scope :open, -> { where.not(status: "resolved") }
  scope :urgent, -> { open.where(severity: [ "high", "critical" ]) }
  scope :due_soon, -> { open.where(due_on: ..14.days.from_now.to_date) }
end
