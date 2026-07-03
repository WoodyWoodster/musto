module Operations
  class ComplianceQuery
    def initialize(employer: Employer.includes(:organization).order(:created_at).first)
      @employer = employer
    end

    def call
      {
        employer: @employer,
        cases: compliance_cases.includes(:employee).order(severity_sort, :due_on),
        documents: documents.includes(:employee).attention_needed.order(:expires_on),
        time_off_requests: time_off_requests.includes(:employee, :time_off_policy).order(:starts_on),
        policies: time_off_policies.order(:name)
      }
    end

    private

    def compliance_cases
      return ComplianceCase.none unless @employer

      @employer.compliance_cases
    end

    def documents
      EmployeeDocument.joins(:employee).where(employees: { employer_id: @employer&.id })
    end

    def time_off_requests
      TimeOffRequest.joins(:employee).where(employees: { employer_id: @employer&.id })
    end

    def time_off_policies
      return TimeOffPolicy.none unless @employer

      @employer.time_off_policies
    end

    def severity_sort
      Arel.sql("CASE severity WHEN 'critical' THEN 0 WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END")
    end
  end
end
