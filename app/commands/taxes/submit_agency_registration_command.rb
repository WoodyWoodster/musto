module Taxes
  class SubmitAgencyRegistrationCommand < ApplicationCommand
    def initialize(dto:, employer_repository: Employers::EmployerRepository.new, repository: nil)
      @dto = dto
      @employer = employer_repository.first_for_operations
      @repository = repository || AgencyRegistrationRepository.new(employer: @employer)
    end

    def call
      return failure(errors: "No employer is available for tax agency registration submission") unless @employer

      registration = @repository.find_registration(@dto.registration_id)
      return failure(record: registration, errors: "Tax agency registration is already submitted") unless registration.submittable?

      @repository.submit_registration(
        registration,
        submitted_by: @dto.submitted_by,
        confirmation_number: @dto.confirmation_number
      )
      success(record: registration.reload)
    rescue ActiveRecord::RecordNotFound
      failure(errors: "Tax agency registration was not found")
    rescue ActiveRecord::RecordInvalid => e
      failure(record: e.record, errors: e.record.errors.full_messages)
    end
  end
end
