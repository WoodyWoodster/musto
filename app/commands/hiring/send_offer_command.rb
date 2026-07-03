module Hiring
  class SendOfferCommand < ApplicationCommand
    def initialize(dto:, employer_repository: Employers::EmployerRepository.new, repository: nil)
      @dto = dto
      @employer = employer_repository.first_for_operations
      @repository = repository || HiringRepository.new(employer: @employer)
    end

    def call
      return failure(errors: "No employer is available for hiring offers") unless @employer

      candidate = @repository.find_candidate(@dto.candidate_id)
      return failure(record: candidate, errors: "Candidate is not in an offerable stage") unless @repository.send_offer(candidate, offered_by: @dto.offered_by)

      success(record: candidate)
    rescue ActiveRecord::RecordNotFound
      failure(errors: "Candidate was not found")
    rescue ActiveRecord::RecordInvalid => e
      failure(record: e.record, errors: e.record.errors.full_messages)
    end
  end
end
