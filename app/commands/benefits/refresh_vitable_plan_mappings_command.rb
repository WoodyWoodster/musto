require "vitable_connect"

module Benefits
  class RefreshVitablePlanMappingsCommand < ApplicationCommand
    def initialize(dto:, employer_repository: Employers::EmployerRepository.new, repository: nil, gateway_class: Vitable::ClientGateway)
      @dto = dto
      @employer = employer_repository.first_for_operations
      @repository = repository || PlanAdministrationRepository.new(employer: @employer)
      @gateway_class = gateway_class
    end

    def call
      return failure(errors: "No employer is available for Vitable plan mapping") unless @employer
      return failure(errors: "No Vitable connection is available for plan mapping") unless @repository.connection

      sync_run = @repository.create_mapping_run(requested_by: @dto.requested_by)

      unless @repository.connection.credentials_present?
        sync_run = @repository.mark_mapping_needs_credentials(sync_run)
        return failure(record: sync_run, errors: sync_run.error_message)
      end

      response = @gateway_class.new(@repository.connection).list_all_plans
      sync_run = @repository.mark_mapping_succeeded(sync_run, response)
      success(record: sync_run, value: response)
    rescue VitableConnect::Errors::APIError => e
      @repository.mark_mapping_failed(sync_run, e)
      failure(record: sync_run, errors: "#{e.class}: #{e.message}")
    rescue ActiveRecord::RecordInvalid => e
      failure(record: e.record, errors: e.record.errors.full_messages)
    end
  end
end
