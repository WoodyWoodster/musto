class EmployeeLifecycleEvent < ApplicationRecord
  belongs_to :employee

  validates :event_type, :effective_on, :status, :summary, :source, presence: true

  scope :pending_review, -> { where(status: "draft") }
  scope :approved, -> { where(status: "approved") }
  scope :queued, -> { where(status: "sync_queued") }

  def draft?
    status == "draft"
  end

  def approved?
    status == "approved"
  end

  def sync_queued?
    status == "sync_queued"
  end

  def termination?
    event_type == "termination"
  end

  def approve!(reviewed_by:)
    update!(
      status: "approved",
      reviewed_at: Time.current,
      metadata: metadata.to_h.merge(
        "reviewed_by" => reviewed_by,
        "reviewed_at" => Time.current.iso8601
      )
    )
  end

  def queue_for_sync!(batch_id:)
    update!(
      status: "sync_queued",
      metadata: metadata.to_h.merge(
        "sync_batch_id" => batch_id,
        "queued_for_sync_at" => Time.current.iso8601
      )
    )
  end
end
