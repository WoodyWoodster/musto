module Vitable
  class GenerateCensusManifestCommand < ApplicationCommand
    def initialize(dto:, employer_repository: Employers::EmployerRepository.new)
      @dto = dto
      @employer = employer_repository.first_for_operations
      @repository = CensusSyncRepository.new(employer: @employer)
    end

    def call
      return failure(errors: "No employer is available for Vitable census sync") unless @employer

      manifest = @repository.generate_manifest(requested_by: @dto.requested_by)
      success(record: @employer.reload, value: manifest)
    rescue ActiveRecord::RecordInvalid => e
      failure(record: e.record, errors: e.record.errors.full_messages)
    end
  end
end
