class OpenEnrollmentCampaign < ApplicationRecord
  STATUSES = %w[draft active closed archived].freeze

  belongs_to :employer

  has_many :open_enrollment_invitations, dependent: :destroy

  validates :name, :plan_year, :starts_on, :ends_on, :status, presence: true
  validates :plan_year, uniqueness: { scope: :employer_id }
  validates :status, inclusion: { in: STATUSES }

  scope :current_first, -> { order(plan_year: :desc, starts_on: :desc) }

  def active?
    status == "active"
  end

  def launched?
    launched_at.present?
  end

  def launch!(requested_by:)
    update!(
      status: "active",
      launched_at: launched_at || Time.current,
      metadata: metadata.to_h.merge(
        "launched_by" => requested_by,
        "launched_at" => Time.current.iso8601
      )
    )
  end
end
