class WebhookEvent < ApplicationRecord
  belongs_to :integration_connection, optional: true

  validates :event_id, :organization_external_id, :event_name, :resource_type,
    :resource_id, :occurred_at, :status, presence: true
  validates :event_id, uniqueness: true

  scope :unprocessed, -> { where(processed_at: nil) }
  scope :for_resource, ->(type, id) { where(resource_type: type, resource_id: id) }

  def processed?
    processed_at.present?
  end
end
