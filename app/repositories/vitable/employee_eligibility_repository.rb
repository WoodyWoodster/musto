module Vitable
  class EmployeeEligibilityRepository < ApplicationRepository
    TERMINATED_STATUSES = %w[terminated inactive ineligible].freeze

    def enrollment_token_block_reason(employee)
      return unless eligibility_terminated?(employee)
      return unless employee.enrollments.any? { |enrollment| enrollment.status == "pending" }

      "Vitable eligibility is terminated; employee must regain eligibility before pending enrollment can launch."
    end

    def deactivate_benefits!(employee:, source:, source_event: nil, reconciled_at: Time.current.iso8601)
      enrollment_ids = []
      deduction_ids = []

      employee.enrollments.where(status: %w[pending accepted]).find_each do |enrollment|
        enrollment.update!(
          status: "inactive",
          accepted_at: nil,
          metadata: enrollment.metadata.to_h.stringify_keys.merge(
            "vitable_lifecycle_status" => "inactive",
            "vitable_lifecycle_source" => source,
            "vitable_lifecycle_reconciled_at" => reconciled_at,
            "vitable_lifecycle_event_id" => source_event&.event_id,
            "vitable_lifecycle_event_name" => source_event&.event_name
          ).compact
        )
        enrollment_ids << enrollment.id

        enrollment.payroll_deductions.find_each do |deduction|
          next if deduction.amount_cents.zero? && deduction.status == "inactive"

          deduction.update!(
            amount_cents: 0,
            status: "inactive",
            metadata: deduction.metadata.to_h.stringify_keys.merge(
              "source" => source,
              "last_reconciled_at" => reconciled_at,
              "last_webhook_event_id" => source_event&.event_id,
              "last_webhook_event_name" => source_event&.event_name,
              "vitable_lifecycle_status" => "inactive"
            ).compact
          )
          deduction_ids << deduction.id
        end
      end

      EmployeeLifecycleReconciliationDto.new(enrollment_ids:, deduction_ids:)
    end

    def eligibility_status(employee)
      employee.metadata.to_h.stringify_keys.fetch("vitable_eligibility_status", nil).presence
    end

    def eligibility_terminated?(employee)
      eligibility_status(employee).to_s.downcase.in?(TERMINATED_STATUSES)
    end
  end
end
