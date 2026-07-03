class Organization < ApplicationRecord
  has_many :employers, dependent: :destroy
  has_many :integration_connections, dependent: :destroy

  validates :name, presence: true
  validates :status, presence: true
  validates :external_id, uniqueness: true, allow_blank: true

  scope :active, -> { where(status: "active") }
end
