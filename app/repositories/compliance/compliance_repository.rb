module Compliance
  class ComplianceRepository < ApplicationRepository
    def initialize(employer: nil)
      @employer = employer
    end

    def cases
      return ComplianceCase.none unless @employer

      @employer.compliance_cases.includes(:employee).order(severity_sort, :due_on)
    end

    def documents
      EmployeeDocument
        .joins(:employee)
        .where(employees: { employer_id: @employer&.id })
        .includes(:employee)
        .attention_needed
        .order(:expires_on)
    end

    def time_off_requests
      TimeOffRequest
        .joins(:employee)
        .where(employees: { employer_id: @employer&.id })
        .includes(:employee, :time_off_policy)
        .order(:starts_on)
    end

    def time_off_policies
      return TimeOffPolicy.none unless @employer

      @employer.time_off_policies.order(:name)
    end

    def open_case_count
      cases.open.count
    end

    def urgent_case_count
      cases.urgent.count
    end

    def pending_time_off_count
      time_off_requests.pending.count
    end

    def find_case(id)
      ComplianceCase.find(id)
    end

    def resolve_case(compliance_case)
      compliance_case.update!(status: "resolved", resolved_at: Time.current)
      compliance_case
    end

    def find_time_off_request(id)
      TimeOffRequest.find(id)
    end

    def review_time_off_request(request, decision)
      request.update!(status: decision, reviewed_at: Time.current)
      request
    end
  end
end
