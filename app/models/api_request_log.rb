class ApiRequestLog < ApplicationRecord
  belongs_to :integration_connection

  validates :operation, :method, :path, presence: true

  scope :recent_first, -> { order(created_at: :desc) }
end
