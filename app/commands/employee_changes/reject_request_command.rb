module EmployeeChanges
  class RejectRequestCommand < ApplicationCommand
    def initialize(dto:, employer_repository: Employers::EmployerRepository.new, repository: nil)
      @dto = dto
      @employer = employer_repository.first_for_operations
      @repository = repository || ChangeRequestRepository.new(employer: @employer)
    end

    def call
      return failure(errors: "No employer is available for employee change rejection") unless @employer

      request = @repository.find_request(@dto.request_id)
      return failure(record: request, errors: "Employee change request is not reviewable") unless @repository.reject_request(request, reviewed_by: @dto.reviewed_by, reason: @dto.reason)

      success(record: request)
    rescue ActiveRecord::RecordNotFound
      failure(errors: "Employee change request was not found")
    rescue ActiveRecord::RecordInvalid => e
      failure(record: e.record, errors: e.record.errors.full_messages)
    end
  end
end
