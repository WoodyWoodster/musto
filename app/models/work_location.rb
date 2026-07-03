class WorkLocation < ApplicationRecord
  belongs_to :employer

  has_many :employees, dependent: :nullify

  validates :name, :country, presence: true
  validates :name, uniqueness: { scope: :employer_id }
end
