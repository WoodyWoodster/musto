class OnboardingTask < ApplicationRecord
  belongs_to :employee

  validates :title, :category, :status, :due_on, :owner, presence: true

  scope :open, -> { where.not(status: "complete") }
  scope :overdue, -> { open.where(due_on: ...Date.current) }

  def overdue?
    status != "complete" && due_on < Date.current
  end
end
