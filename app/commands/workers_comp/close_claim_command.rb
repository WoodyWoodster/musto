module WorkersComp
  class CloseClaimCommand < ApplicationCommand
    def initialize(dto:, employer_repository: Employers::EmployerRepository.new, repository: nil)
      @dto = dto
      @employer = employer_repository.first_for_operations
      @repository = repository || CoverageRepository.new(employer: @employer)
    end

    def call
      return failure(errors: "No employer is available for workers comp claim closure") unless @employer

      claim = @repository.find_claim(@dto.id)
      return failure(record: claim, errors: "Workers comp claim is not closable") unless @repository.close_claim(claim, closed_by: @dto.closed_by, resolution: @dto.resolution)

      success(record: claim.reload)
    rescue ActiveRecord::RecordNotFound
      failure(errors: "Workers comp claim was not found")
    rescue ActiveRecord::RecordInvalid => e
      failure(record: e.record, errors: e.record.errors.full_messages)
    end
  end
end
