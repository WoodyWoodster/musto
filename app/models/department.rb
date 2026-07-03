class Department < ApplicationRecord
  belongs_to :employer
  belongs_to :manager, class_name: "Employee", optional: true

  has_many :employees, dependent: :nullify
  has_many :job_openings, dependent: :nullify

  validates :name, :code, presence: true
  validates :code, uniqueness: { scope: :employer_id }
  validates :budget_cents, numericality: { greater_than_or_equal_to: 0 }
end
