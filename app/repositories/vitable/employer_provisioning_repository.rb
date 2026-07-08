module Vitable
  class EmployerProvisioningRepository < ApplicationRepository
    PACKET_KEY = "vitable_employer_provisioning_packet"
    PROVISIONING_OPERATIONS = %w[employer_create employer_settings_update].freeze
    REQUEST_OPERATIONS = %w[employer.create employer.update_settings employer.eligibility_policy.create].freeze
    ELIGIBILITY_CLASSIFICATIONS = [ "All", "Full time", "Part time" ].freeze
    ELIGIBILITY_WAITING_PERIODS = [ "1st of the following month", "30 days", "60 days", "None" ].freeze
    VITABLE_PAY_FREQUENCIES = %w[weekly bi_weekly semi_monthly monthly].freeze

    def initialize(employer:)
      @employer = employer
    end

    def connection
      @connection ||= vitable_connection_for(@employer&.organization)
    end

    def latest_packet
      @employer&.settings.to_h.fetch(PACKET_KEY, nil)
    end

    def preview_packet(requested_by: "ops_console")
      build_packet(requested_by:)
    end

    def sync_runs(limit: 12)
      return SyncRun.none unless connection

      connection.sync_runs.where(operation: PROVISIONING_OPERATIONS).recent_first.limit(limit)
    end

    def request_logs(limit: 12)
      return ApiRequestLog.none unless connection

      connection.api_request_logs.where(operation: REQUEST_OPERATIONS).recent_first.limit(limit)
    end

    def generate_packet(requested_by:)
      packet = build_packet(requested_by:)
      @employer.update!(settings: @employer.settings.to_h.merge(PACKET_KEY => packet))
      packet
    end

    def create_sync_run(packet:, operation:, requested_by:)
      connection.sync_runs.create!(
        resource_type: "employer",
        operation:,
        status: "running",
        started_at: Time.current,
        stats: sync_stats(packet:, operation:, requested_by:)
      )
    end

    def mark_blocked(sync_run, message)
      sync_run.update!(
        status: "blocked",
        completed_at: Time.current,
        error_message: message,
        stats: sync_run.stats.to_h.merge("blocked_reason" => message)
      )
      sync_run
    end

    def mark_needs_credentials(sync_run)
      message = "#{connection.api_key_reference} is not configured"
      sync_run.update!(
        status: "needs_credentials",
        completed_at: Time.current,
        error_message: message,
        stats: sync_run.stats.to_h.merge("blocked_reason" => message)
      )
      sync_run
    end

    def mark_succeeded(sync_run, response, packet:)
      response_hash = serialize_response(response)
      remote_employer_id = extract_remote_employer_id(response_hash)
      synced_at = Time.current.iso8601
      settings = @employer.settings.to_h.merge(
        "vitable_employer_provisioned_at" => synced_at,
        "vitable_employer_provisioning_last_sync" => {
          "synced_at" => synced_at,
          "operation" => sync_run.operation,
          "packet_id" => packet.fetch("packet_id"),
          "mode" => packet.fetch("mode"),
          "remote_employer_id" => remote_employer_id.presence || @employer.vitable_id
        },
        "vitable_pay_frequency" => packet.fetch("settings_payload", {}).fetch("pay_frequency", nil),
        "vitable_eligibility_policy" => eligibility_policy_profile(packet, response_hash, synced_at)
      )
      @employer.update!(vitable_id: remote_employer_id) if remote_employer_id.present? && @employer.vitable_id.blank?
      @employer.update!(settings:)

      sync_run.update!(
        status: "succeeded",
        completed_at: Time.current,
        error_message: nil,
        stats: sync_run.stats.to_h.merge(
          "remote_response" => response_hash,
          "remote_employer_id" => remote_employer_id.presence || @employer.vitable_id,
          "remote_synced_at" => synced_at
        )
      )
      sync_run
    end

    def mark_failed(sync_run, error, response: nil)
      return unless sync_run

      completed_at = Time.current
      stats = sync_run.stats.to_h.merge("error_class" => error.class.name)

      if response
        response_hash = serialize_response(response)
        stats = stats.merge(
          "response_class" => response.class.name,
          "remote_response" => response_hash,
          "fetched_at" => completed_at.iso8601
        )
      end

      sync_run.update!(
        status: "failed",
        completed_at:,
        error_message: PayloadRedactor.error_message(error),
        stats:
      )
      sync_run
    end

    private

    def build_packet(requested_by:)
      create_payload = create_payload_for(primary_location)
      settings_payload = { "pay_frequency" => vitable_pay_frequency }
      eligibility_profile = eligibility_profile_for
      mode = @employer.vitable_id.present? ? "update_settings" : "create"
      holdbacks = holdbacks_for(mode:, create_payload:, settings_payload:, eligibility_profile:)
      endpoint = mode == "create" ? "/v1/employers" : "/v1/employers/:employer_id/settings"
      eligibility_policy_endpoint = "/v1/employers/:employer_id/benefit-eligibility-policies"

      {
        "packet_id" => "vitable_employer_provisioning_#{@employer.id}_#{Time.current.to_i}",
        "generated_at" => Time.current.iso8601,
        "requested_by" => requested_by,
        "employer_id" => @employer.id,
        "remote_employer_id" => @employer.vitable_id,
        "endpoint" => endpoint,
        "endpoint_sequence" => endpoint_sequence_for(mode, eligibility_policy_endpoint),
        "mode" => mode,
        "status" => holdbacks.any? ? "blocked" : "ready",
        "totals" => {
          "payload_field_count" => create_payload.except("address").values.compact.count + create_payload.fetch("address", {}).values.compact.count + settings_payload.values.compact.count,
          "missing_field_count" => holdbacks.count,
          "holdback_count" => holdbacks.count
        },
        "create_payload" => create_payload,
        "settings_payload" => settings_payload,
        "eligibility_policy_payload" => eligibility_profile,
        "eligibility_policy_endpoint" => eligibility_policy_endpoint,
        "eligibility_policy_action" => eligibility_policy_current?(eligibility_profile) ? "skip_remote_current" : "submit",
        "api_payload" => {
          "create" => create_payload,
          "settings" => settings_payload,
          "eligibility_policy" => eligibility_profile
        },
        "holdbacks" => holdbacks
      }
    end

    def create_payload_for(location)
      {
        "name" => @employer.name,
        "legal_name" => @employer.legal_name,
        "ein" => formatted_ein,
        "email" => billing_email,
        "phone_number" => phone_number,
        "reference_id" => "musto_employer_#{@employer.id}",
        "address" => address_payload_for(location)
      }.compact
    end

    def address_payload_for(location)
      return {} unless location

      {
        "address_line_1" => location.address_line1&.strip,
        "city" => location.city&.strip,
        "state" => location.state&.strip&.upcase,
        "zipcode" => location.postal_code&.strip
      }.compact
    end

    def eligibility_profile_for
      {
        "classification" => settings.fetch("eligibility_classification", "All").presence,
        "waiting_period" => settings.fetch("eligibility_waiting_period", "1st of the following month").presence
      }.compact
    end

    def holdbacks_for(mode:, create_payload:, settings_payload:, eligibility_profile:)
      holdbacks = []

      if mode == "create"
        required_create_fields(create_payload).each do |field, value|
          next if value.present?

          holdbacks << holdback(field:, reason_code: "missing_required_field", reason: "#{field.to_s.humanize} is required before creating a Vitable employer.")
        end

        holdbacks.concat(create_payload_format_holdbacks(create_payload))
      end

      pay_frequency = settings_payload.fetch("pay_frequency", nil)
      if pay_frequency.blank?
        holdbacks << holdback(field: "pay_frequency", reason_code: "missing_pay_frequency", reason: "Pay frequency is required before Vitable employer settings can be updated.")
      elsif !VITABLE_PAY_FREQUENCIES.include?(pay_frequency)
        holdbacks << holdback(field: "pay_frequency", reason_code: "unsupported_pay_frequency", reason: "Pay frequency must be one of #{VITABLE_PAY_FREQUENCIES.map(&:humanize).to_sentence}.")
      end

      required_eligibility_profile_fields(eligibility_profile).each do |field, value|
        next if value.present?

        holdbacks << holdback(field:, reason_code: "missing_eligibility_profile_field", reason: "#{field.to_s.humanize} is required before the Vitable eligibility profile is ready.")
      end

      classification = eligibility_profile.fetch("classification", nil)
      if classification.present? && !ELIGIBILITY_CLASSIFICATIONS.include?(classification)
        holdbacks << holdback(field: "classification", reason_code: "unsupported_eligibility_classification", reason: "Classification must be one of #{ELIGIBILITY_CLASSIFICATIONS.to_sentence}.")
      end

      waiting_period = eligibility_profile.fetch("waiting_period", nil)
      if waiting_period.present? && !ELIGIBILITY_WAITING_PERIODS.include?(waiting_period)
        holdbacks << holdback(field: "waiting_period", reason_code: "unsupported_eligibility_waiting_period", reason: "Waiting period must be one of #{ELIGIBILITY_WAITING_PERIODS.to_sentence}.")
      end

      holdbacks
    end

    def required_create_fields(create_payload)
      {
        name: create_payload.fetch("name", nil),
        legal_name: create_payload.fetch("legal_name", nil),
        ein: create_payload.fetch("ein", nil),
        billing_email: create_payload.fetch("email", nil),
        address_line_1: create_payload.dig("address", "address_line_1"),
        city: create_payload.dig("address", "city"),
        state: create_payload.dig("address", "state"),
        zipcode: create_payload.dig("address", "zipcode")
      }
    end

    def create_payload_format_holdbacks(create_payload)
      [
        invalid_present_format_holdback("ein", create_payload.fetch("ein", nil), "invalid_ein_format", "EIN must use XX-XXXXXXX before creating a Vitable employer.") { |value| valid_ein?(value) },
        invalid_present_format_holdback("billing_email", create_payload.fetch("email", nil), "invalid_billing_email", "Billing email must be a valid email address before creating a Vitable employer.") { |value| valid_email?(value) },
        invalid_format_holdback("phone_number", "invalid_phone_number", "Phone number must contain 10 US digits when supplied.") { valid_optional_phone?(create_payload.fetch("phone_number", nil)) },
        invalid_present_format_holdback("state", create_payload.dig("address", "state"), "invalid_state_code", "State must be a two-letter code before creating a Vitable employer.") { |value| valid_state?(value) },
        invalid_present_format_holdback("zipcode", create_payload.dig("address", "zipcode"), "invalid_zipcode", "ZIP code must be a 5-digit or ZIP+4 code before creating a Vitable employer.") { |value| valid_zipcode?(value) }
      ].compact
    end

    def invalid_present_format_holdback(field, value, reason_code, reason)
      return if value.blank? || yield(value)

      holdback(field:, reason_code:, reason:)
    end

    def invalid_format_holdback(field, reason_code, reason)
      return if yield

      holdback(field:, reason_code:, reason:)
    end

    def required_eligibility_profile_fields(eligibility_profile)
      {
        classification: eligibility_profile.fetch("classification", nil),
        waiting_period: eligibility_profile.fetch("waiting_period", nil)
      }
    end

    def holdback(field:, reason_code:, reason:)
      {
        "field" => field.to_s,
        "status" => "blocked",
        "reason_code" => reason_code,
        "reason" => reason
      }
    end

    def primary_location
      locations = @employer.work_locations.order(:id).to_a
      locations.find { |location| !location.remote? && address_complete?(location) } ||
        locations.find { |location| address_complete?(location) } ||
        locations.find { |location| !location.remote? } ||
        locations.first
    end

    def address_complete?(location)
      [ location.address_line1, location.city, location.state, location.postal_code ].all?(&:present?)
    end

    def billing_email
      (settings.fetch("billing_email", nil).presence || settings.fetch("benefits_email", nil).presence)&.strip&.downcase
    end

    def phone_number
      raw = settings.fetch("phone_number", nil).presence || settings.fetch("billing_phone", nil).presence
      digits = raw.to_s.gsub(/\D/, "")
      digits = digits.delete_prefix("1") if digits.length == 11 && digits.start_with?("1")
      digits.presence
    end

    def vitable_pay_frequency
      local_frequency = settings.fetch("pay_frequency", nil).to_s.tr("-", "_")
      {
        "weekly" => "weekly",
        "biweekly" => "bi_weekly",
        "bi_weekly" => "bi_weekly",
        "semimonthly" => "semi_monthly",
        "semi_monthly" => "semi_monthly",
        "monthly" => "monthly"
      }.fetch(local_frequency, local_frequency.presence)
    end

    def formatted_ein
      raw = @employer.ein.to_s.strip
      digits = raw.gsub(/\D/, "")
      return raw unless digits.length == 9

      "#{digits[0, 2]}-#{digits[2, 7]}"
    end

    def valid_ein?(value)
      value.to_s.match?(/\A\d{2}-\d{7}\z/)
    end

    def valid_email?(value)
      value.to_s.match?(/\A[^@\s]+@[^@\s]+\.[^@\s]+\z/)
    end

    def valid_optional_phone?(value)
      value.blank? || value.to_s.match?(/\A\d{10}\z/)
    end

    def valid_state?(value)
      value.to_s.match?(/\A[A-Z]{2}\z/)
    end

    def valid_zipcode?(value)
      value.to_s.match?(/\A\d{5}(-\d{4})?\z/)
    end

    def settings
      @settings ||= @employer.settings.to_h.stringify_keys
    end

    def sync_stats(packet:, operation:, requested_by:)
      {
        "packet_id" => packet.fetch("packet_id"),
        "requested_by" => requested_by,
        "operation" => operation,
        "mode" => packet.fetch("mode"),
        "resource_id" => @employer.vitable_id.presence || "local_employer_#{@employer.id}",
        "endpoint" => packet.fetch("endpoint"),
        "endpoint_sequence" => packet.fetch("endpoint_sequence", [ packet.fetch("endpoint") ]),
        "payload" => packet.fetch("api_payload", {})
      }
    end

    def serialize_response(response)
      serialized =
        if response.blank?
          {}
        elsif response.respond_to?(:deep_to_h)
          response.deep_to_h
        elsif response.respond_to?(:to_h)
          response.to_h
        else
          { "value" => response.to_s }
        end

      PayloadRedactor.redact(serialized.deep_stringify_keys)
    end

    def extract_remote_employer_id(response_hash)
      response_hash.dig("employer_response", "data", "id") ||
        response_hash.dig("employer_response", "data", "employer", "id") ||
        response_hash.dig("employer_response", "id") ||
        response_hash.dig("data", "employer", "id") ||
        response_hash.dig("data", "id") ||
        response_hash.fetch("remote_employer_id", nil) ||
        response_hash.fetch("id", nil)
    end

    def eligibility_policy_profile(packet, response_hash, synced_at)
      profile = packet.fetch("eligibility_policy_payload", {}).to_h.stringify_keys
      previous = @employer.settings.to_h.fetch("vitable_eligibility_policy", {}).to_h.stringify_keys
      submission = EmployerEligibilityPolicySubmissionDto.from_hash(response_hash.fetch("eligibility_policy_submission", {}))

      previous.merge(
        profile.merge(
          "status" => submission.status,
          "source" => submission.source,
          "synced_with_employer_at" => synced_at,
          "submitted_at" => submission.submitted_at&.iso8601,
          "remote_employer_id" => submission.remote_employer_id.presence || @employer.vitable_id,
          "remote_response" => submission.remote_response,
          "endpoint" => submission.endpoint,
          "webhook_event_name" => "employer.eligibility_policy_created"
        )
      ).compact
    end

    def endpoint_sequence_for(mode, eligibility_policy_endpoint)
      endpoints = []
      endpoints << "/v1/employers" if mode == "create"
      endpoints << "/v1/employers/:employer_id/settings"
      endpoints << eligibility_policy_endpoint
      endpoints
    end

    def eligibility_policy_current?(profile)
      existing = @employer.settings.to_h.fetch("vitable_eligibility_policy", {}).to_h.stringify_keys
      existing.fetch("source", nil).in?([ "remote_api", "remote_existing" ]) &&
        existing.fetch("classification", nil) == profile.fetch("classification", nil) &&
        existing.fetch("waiting_period", nil) == profile.fetch("waiting_period", nil)
    end
  end
end
