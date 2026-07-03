class SyncRun < ApplicationRecord
  belongs_to :integration_connection

  validates :resource_type, :operation, :status, :started_at, presence: true

  scope :recent_first, -> { order(created_at: :desc) }
end
