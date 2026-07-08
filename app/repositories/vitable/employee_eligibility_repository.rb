module Vitable
  class EmployeeEligibilityRepository < ApplicationRepository
    TERMINATED_STATUSES = %w[terminated inactive ineligible].freeze

    def enrollment_token_block_reason(employee)
      return unless eligibility_terminated?(employee)
      return unless employee.enrollments.any? { |enrollment| enrollment.status == "pending" }

      "Vitable eligibility is terminated; employee must regain eligibility before pending enrollment can launch."
    end

    def eligibility_status(employee)
      employee.metadata.to_h.stringify_keys.fetch("vitable_eligibility_status", nil).presence
    end

    def eligibility_terminated?(employee)
      eligibility_status(employee).to_s.downcase.in?(TERMINATED_STATUSES)
    end
  end
end
