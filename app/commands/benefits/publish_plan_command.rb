module Benefits
  class PublishPlanCommand < ApplicationCommand
    def initialize(dto:, employer_repository: Employers::EmployerRepository.new, repository: nil)
      @dto = dto
      @employer = employer_repository.first_for_operations
      @repository = repository || PlanAdministrationRepository.new(employer: @employer)
    end

    def call
      return failure(errors: "No employer is available for benefit plan publishing") unless @employer

      plan = @repository.find_plan(@dto.plan_id)
      return failure(record: plan, errors: @repository.readiness_issues(plan).map(&:reason)) unless @repository.publish_plan(plan, published_by: @dto.published_by)

      success(record: plan.reload)
    rescue ActiveRecord::RecordNotFound
      failure(errors: "Benefit plan was not found")
    rescue ActiveRecord::RecordInvalid => e
      failure(record: e.record, errors: e.record.errors.full_messages)
    end
  end
end
