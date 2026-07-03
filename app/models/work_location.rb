class WorkLocation < ApplicationRecord
  belongs_to :employer

  has_many :employees, dependent: :nullify
  has_many :job_openings, dependent: :nullify
  has_many :tax_agency_registrations, dependent: :nullify

  validates :name, :country, presence: true
  validates :name, uniqueness: { scope: :employer_id }
end
