module Operations
  class WorkforceQuery
    def initialize(employer_repository: Employers::EmployerRepository.new)
      @employer = employer_repository.first_for_operations
      @repository = Workforce::WorkforceRepository.new(employer: @employer)
    end

    def call
      {
        employer: EmployerContextDto.from_record(@employer),
        departments: @repository.departments.map { |department| DepartmentDto.from_record(department) },
        locations: @repository.locations.map { |location| WorkLocationDto.from_record(location) },
        employees: @repository.employees.map { |employee| WorkforceEmployeeDto.from_record(employee) },
        onboarding_tasks: @repository.onboarding_tasks.map { |task| OnboardingTaskDto.from_record(task) },
        open_onboarding_count: @repository.open_onboarding_count,
        documents: @repository.documents.map { |document| DocumentExceptionDto.from_record(document) },
        documents_attention_count: @repository.documents_attention_count
      }
    end
  end
end
