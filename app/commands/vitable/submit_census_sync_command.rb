module Vitable
  class SubmitCensusSyncCommand < ApplicationCommand
    def initialize(dto:, employer_repository: Employers::EmployerRepository.new, gateway_class: ClientGateway)
      @dto = dto
      @employer = employer_repository.first_for_operations
      @repository = CensusSyncRepository.new(employer: @employer)
      @gateway_class = gateway_class
    end

    def call
      response = nil
      return failure(errors: "No employer is available for Vitable census sync") unless @employer
      return failure(errors: "No Vitable connection is available for census sync") unless @repository.connection

      manifest = @repository.latest_manifest || @repository.generate_manifest(requested_by: @dto.requested_by)
      sync_run = @repository.create_sync_run(manifest:, requested_by: @dto.requested_by)

      return blocked(sync_run, "Remote Vitable employer ID is missing") if @employer.vitable_id.blank?
      return blocked(sync_run, "Generate at least one ready employee row before submitting census sync") if ready_employees(manifest).empty?

      unless @repository.connection.credentials_present?
        sync_run = @repository.mark_sync_needs_credentials(sync_run)
        return failure(record: sync_run, value: manifest, errors: sync_run.error_message)
      end

      response = @gateway_class.new(@repository.connection).submit_census_sync(@employer.vitable_id, ready_employees(manifest))
      sync_run = @repository.mark_sync_succeeded(sync_run, response)
      success(record: sync_run, value: response)
    rescue VitableConnect::Errors::APIError => e
      @repository.mark_sync_failed(sync_run, e)
      failure(record: sync_run, errors: "#{e.class}: #{e.message}")
    rescue ArgumentError => e
      @repository.mark_sync_failed(sync_run, e, response:)
      failure(record: sync_run, errors: e.message)
    rescue ActiveRecord::RecordInvalid => e
      failure(record: e.record, errors: e.record.errors.full_messages)
    end

    private

    def ready_employees(manifest)
      manifest.fetch("api_payload", {}).fetch("employees", [])
    end

    def blocked(sync_run, message)
      sync_run = @repository.mark_sync_blocked(sync_run, message)
      failure(record: sync_run, value: @repository.latest_manifest, errors: message)
    end
  end
end
