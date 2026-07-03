class ShiftSwapRequest < ApplicationRecord
  STATUSES = %w[submitted approved denied canceled].freeze

  belongs_to :work_shift
  belongs_to :requester, class_name: "Employee"
  belongs_to :target_employee, class_name: "Employee", optional: true

  validates :status, presence: true, inclusion: { in: STATUSES }
  validate :employees_belong_to_shift_employer

  scope :current_first, -> { order(status: :asc, submitted_at: :desc, created_at: :desc) }

  def submitted?
    status == "submitted"
  end

  def approved?
    status == "approved"
  end

  def reviewable?
    submitted?
  end

  def approve!(reviewed_by:)
    transaction do
      work_shift.update!(
        employee: target_employee || requester,
        metadata: work_shift.metadata.to_h.merge(
          "swap_request_id" => id,
          "swap_approved_by" => reviewed_by,
          "swap_approved_at" => Time.current.iso8601
        )
      )
      update!(
        status: "approved",
        reviewed_at: Time.current,
        reviewed_by:,
        metadata: metadata.to_h.merge(
          "approved_by" => reviewed_by,
          "approved_at" => Time.current.iso8601
        )
      )
    end
  end

  private

  def employees_belong_to_shift_employer
    employer_id = work_shift&.employer_id
    return if employer_id.blank?

    errors.add(:requester, "must belong to the shift employer") if requester.present? && requester.employer_id != employer_id
    errors.add(:target_employee, "must belong to the shift employer") if target_employee.present? && target_employee.employer_id != employer_id
  end
end
