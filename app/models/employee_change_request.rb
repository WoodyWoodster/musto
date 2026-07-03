class EmployeeChangeRequest < ApplicationRecord
  REQUEST_TYPES = %w[profile_update direct_deposit tax_withholding emergency_contact work_location].freeze
  STATUSES = %w[submitted applied sync_queued rejected].freeze

  belongs_to :employee

  validates :request_type, :title, :status, :effective_on, :submitted_at, presence: true
  validates :request_type, inclusion: { in: REQUEST_TYPES }
  validates :status, inclusion: { in: STATUSES }

  scope :submitted, -> { where(status: "submitted") }
  scope :applied, -> { where(status: "applied") }
  scope :queued, -> { where(status: "sync_queued") }
  scope :rejected, -> { where(status: "rejected") }

  def submitted?
    status == "submitted"
  end

  def applied?
    status == "applied"
  end

  def sync_queued?
    status == "sync_queued"
  end

  def rejected?
    status == "rejected"
  end

  def reviewable?
    submitted?
  end

  def payload
    metadata.to_h.stringify_keys.fetch("payload", {}).to_h.stringify_keys
  end

  def impact
    metadata.to_h.stringify_keys.fetch("impact", {}).to_h.stringify_keys
  end

  def payroll_impact
    impact.fetch("payroll", "none")
  end

  def benefits_impact
    impact.fetch("benefits", "none")
  end

  def compliance_impact
    impact.fetch("compliance", "none")
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
