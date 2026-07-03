module Operations
  class ComplianceQuery
    def initialize(employer_repository: Employers::EmployerRepository.new)
      @employer = employer_repository.first_for_operations
      @repository = Compliance::ComplianceRepository.new(employer: @employer)
    end

    def call
      {
        employer: EmployerContextDto.from_record(@employer),
        cases: @repository.cases.map { |compliance_case| ComplianceCaseDto.from_record(compliance_case) },
        open_case_count: @repository.open_case_count,
        urgent_case_count: @repository.urgent_case_count,
        documents: @repository.documents.map { |document| DocumentExceptionDto.from_record(document) },
        time_off_requests: @repository.time_off_requests.map { |request| TimeOffRequestDto.from_record(request) },
        pending_time_off_count: @repository.pending_time_off_count,
        policies: @repository.time_off_policies.map { |policy| TimeOffPolicyDto.from_record(policy) }
      }
    end
  end
end
