module EmployeeChanges
  class ApproveRequestCommand < ApplicationCommand
    def initialize(dto:, employer_repository: Employers::EmployerRepository.new, repository: nil)
      @dto = dto
      @employer = employer_repository.first_for_operations
      @repository = repository || ChangeRequestRepository.new(employer: @employer)
    end

    def call
      return failure(errors: "No employer is available for employee change approval") unless @employer

      request = @repository.find_request(@dto.request_id)
      return failure(record: request, errors: "Employee change request is not reviewable") unless @repository.approve_request(request, reviewed_by: @dto.reviewed_by)

      success(record: request)
    rescue ActiveRecord::RecordNotFound
      failure(errors: "Employee change request was not found")
    rescue ActiveRecord::RecordInvalid => e
      failure(record: e.record, errors: e.record.errors.full_messages)
    rescue KeyError => e
      failure(errors: "Missing required change payload field: #{e.key}")
    end
  end
end
