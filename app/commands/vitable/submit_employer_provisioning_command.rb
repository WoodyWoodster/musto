module Vitable
  class SubmitEmployerProvisioningCommand < ApplicationCommand
    def initialize(dto:, employer_repository: Employers::EmployerRepository.new, gateway_class: ClientGateway)
      @dto = dto
      @employer = employer_repository.first_for_operations
      @repository = EmployerProvisioningRepository.new(employer: @employer)
      @gateway_class = gateway_class
    end

    def call
      response = {}
      return failure(errors: "No employer is available for Vitable employer provisioning") unless @employer
      return failure(errors: "No Vitable connection is available for employer provisioning") unless @repository.connection

      packet = @repository.latest_packet || @repository.generate_packet(requested_by: @dto.requested_by)
      operation = packet.fetch("mode") == "create" ? "employer_create" : "employer_settings_update"
      sync_run = @repository.create_sync_run(packet:, operation:, requested_by: @dto.requested_by)

      return blocked(sync_run, "Resolve provisioning packet holdbacks before submitting") if packet.fetch("status") == "blocked"

      unless @repository.connection.credentials_present?
        sync_run = @repository.mark_needs_credentials(sync_run)
        return failure(record: sync_run, value: packet, errors: sync_run.error_message)
      end

      response = submit_packet(packet, response:)
      sync_run = @repository.mark_succeeded(sync_run, response, packet:)
      success(record: sync_run, value: response)
    rescue ::VitableConnect::Errors::APIError => e
      @repository.mark_failed(sync_run, e, response: response.presence)
      failure(record: sync_run, errors: PayloadRedactor.error_with_class(e))
    rescue ArgumentError => e
      @repository.mark_failed(sync_run, e, response: response.presence)
      failure(record: sync_run, errors: PayloadRedactor.error_message(e))
    rescue ActiveRecord::RecordInvalid => e
      failure(record: e.record, errors: e.record.errors.full_messages)
    end

    private

    def submit_packet(packet, response:)
      gateway = @gateway_class.new(@repository.connection)
      remote_employer_id = @employer.vitable_id
      employer_response = nil

      if packet.fetch("mode") == "create"
        employer_response = gateway.create_employer(packet.fetch("create_payload"))
        response["employer_response"] = serialize_response(employer_response)
        employer_dto = RemoteEmployerResponseDto
          .from_hash(response.fetch("employer_response"))
          .validate_create!(expected_reference_id: packet.dig("create_payload", "reference_id"))
        remote_employer_id = employer_dto.remote_employer_id

        @employer.update!(vitable_id: remote_employer_id) if @employer.vitable_id.blank?
      end
      raise ArgumentError, "Vitable employer ID is required before employer settings can be updated" if remote_employer_id.blank?

      response["remote_employer_id"] = remote_employer_id
      pay_frequency = packet.fetch("settings_payload").fetch("pay_frequency")
      settings_response = gateway.update_employer_settings(remote_employer_id, pay_frequency)
      response["settings_response"] = serialize_response(settings_response)
      RemoteEmployerSettingsResponseDto
        .from_hash(response.fetch("settings_response"))
        .validate!(expected_pay_frequency: pay_frequency)
      policy_submission = submit_eligibility_policy(gateway, remote_employer_id, packet, response:)

      response.delete("eligibility_policy_response")
      response["employer_response"] ||= {}
      response.merge(
        "eligibility_policy_submission" => policy_submission.to_metadata
      )
    end

    def submit_eligibility_policy(gateway, remote_employer_id, packet, response:)
      payload = packet.fetch("eligibility_policy_payload")
      submitted_at = Time.current
      return EmployerEligibilityPolicySubmissionDto.skipped(remote_employer_id:, payload:, submitted_at:) if packet.fetch("eligibility_policy_action") == "skip_remote_current"

      policy_response = gateway.create_eligibility_policy(remote_employer_id, payload)
      response["eligibility_policy_response"] = serialize_response(policy_response)
      RemoteEligibilityPolicyResponseDto
        .from_hash(response.fetch("eligibility_policy_response"))
        .validate!(expected_employer_id: remote_employer_id)
      EmployerEligibilityPolicySubmissionDto.submitted(remote_employer_id:, payload:, response: policy_response, submitted_at:)
    rescue ::VitableConnect::Errors::APIStatusError => e
      raise unless e.status == 422

      EmployerEligibilityPolicySubmissionDto.existing(remote_employer_id:, payload:, error: e, submitted_at:)
    end

    def serialize_response(response)
      return {} if response.blank?
      return response.deep_to_h.deep_stringify_keys if response.respond_to?(:deep_to_h)
      return response.to_h.deep_stringify_keys if response.respond_to?(:to_h)

      { "value" => response.to_s }
    end

    def blocked(sync_run, message)
      sync_run = @repository.mark_blocked(sync_run, message)
      failure(record: sync_run, value: @repository.latest_packet, errors: message)
    end
  end
end
