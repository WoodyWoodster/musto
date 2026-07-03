module Operations
  class BenefitsQuery
    def initialize(
      employer_repository: Employers::EmployerRepository.new,
      integration_repository: Vitable::IntegrationRepository.new
    )
      @employer = employer_repository.first_for_operations
      @repository = Benefits::BenefitsRepository.new(employer: @employer)
      @integration_repository = integration_repository
    end

    def call
      {
        employer: EmployerContextDto.from_record(@employer),
        benefit_plans: @repository.plans.map { |plan| BenefitPlanDto.from_record(plan) },
        enrollments: @repository.enrollments.map { |enrollment| EnrollmentDto.from_record(enrollment) },
        accepted_enrollment_count: @repository.accepted_enrollment_count,
        pending_enrollment_count: @repository.pending_enrollment_count,
        connections: @integration_repository.vitable_connections.map { |connection| IntegrationConnectionDto.from_record(connection) },
        webhooks: @integration_repository.webhooks(limit: 12).map { |event| IntegrationWebhookEventDto.from_record(event) }
      }
    end
  end
end
