module Vitable
  class EligibilityPolicySnapshotRepository < ApplicationRepository
    def initialize(connection:)
      @connection = connection
    end

    def reconcile_snapshot(snapshot_entries:, source:, refreshed_at: Time.current.iso8601)
      Array(snapshot_entries).reduce(EligibilityPolicySnapshotReconciliationDto.empty) do |result, entry|
        reconcile_policy(
          result:,
          entry: entry.to_h.stringify_keys,
          source:,
          refreshed_at:
        )
      end
    end

    private

    def reconcile_policy(result:, entry:, source:, refreshed_at:)
      return result.increment(processed_count: 1, error_count: 1) if entry.fetch("error_class", nil).present?

      response_hash = entry.fetch("policy", {}).to_h.stringify_keys
      dto = RemoteEligibilityPolicyResponseDto
        .from_hash(response_hash)
        .validate!(expected_employer_id: entry.fetch("remote_employer_id", nil).presence)
      employer = employer_for(entry, dto)
      return result.increment(processed_count: 1, unmatched_count: 1) unless employer

      changed = update_employer(employer, entry, dto, source:, refreshed_at:)
      result.increment(
        processed_count: 1,
        matched_count: 1,
        updated_count: changed ? 1 : 0,
        unchanged_count: changed ? 0 : 1
      )
    end

    def update_employer(employer, entry, dto, source:, refreshed_at:)
      profile = employer.settings.to_h.fetch("vitable_eligibility_policy", {}).to_h.stringify_keys
      remote_policy = dto.raw_payload.to_h.stringify_keys
      response_hash = entry.fetch("policy", {}).to_h.stringify_keys
      updated_profile = profile.merge(
        remote_policy.slice("classification", "waiting_period").compact
      ).merge(
        "status" => "remote_current",
        "source" => source,
        "remote_employer_id" => dto.remote_employer_id,
        "remote_policy_id" => dto.remote_policy_id,
        "remote_snapshot" => response_hash,
        "retrieve_endpoint" => "/v1/benefit-eligibility-policies/#{dto.remote_policy_id}",
        "last_refreshed_at" => refreshed_at,
        "last_snapshot_source" => source
      ).compact

      settings = employer.settings.to_h.stringify_keys.merge("vitable_eligibility_policy" => updated_profile)
      employer.assign_attributes(settings:)
      changed = employer.has_changes_to_save?
      employer.save! if changed
      changed
    end

    def employer_for(entry, dto)
      local_employer_id = entry.fetch("local_employer_id", nil)
      employer = employer_scope.find_by(id: local_employer_id) if local_employer_id.present?
      return employer if employer

      employer_scope.find_by(vitable_id: dto.remote_employer_id)
    end

    def employer_scope
      @connection.organization.employers
    end
  end
end
