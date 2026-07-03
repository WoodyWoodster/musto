class TimeOffPolicy < ApplicationRecord
  belongs_to :employer

  has_many :time_off_requests, dependent: :restrict_with_error

  validates :name, :accrual_method, :status, presence: true
  validates :annual_hours, :carryover_hours, numericality: { greater_than_or_equal_to: 0 }
  validates :name, uniqueness: { scope: :employer_id }

  scope :active, -> { where(status: "active") }
end
