module Vitable
  class RemoteGroupSnapshotRepository < ApplicationRepository
    SNAPSHOT_KEY = "vitable_care_group_snapshot"
    CONFLICT_KEY = "vitable_care_group_conflict"

    def initialize(connection:)
      @connection = connection
    end

    def reconcile_snapshot(remote_groups:, source:, refreshed_at: Time.current.iso8601)
      Array(remote_groups).reduce(RemoteGroupSnapshotReconciliationDto.empty) do |result, remote_group|
        reconcile_group(
          result:,
          remote_group: remote_group.to_h.stringify_keys,
          source:,
          refreshed_at:
        )
      end
    end

    private

    def reconcile_group(result:, remote_group:, source:, refreshed_at:)
      validate_remote_group_identity!(remote_group)
      employer, matched_by = employer_for_remote(remote_group)
      return result.increment(processed_count: 1, unmatched_count: 1) unless employer

      if remote_id_conflict?(employer, remote_id(remote_group))
        record_conflict(employer, remote_group, matched_by:, source:, refreshed_at:)
        return result.increment(processed_count: 1, conflict_count: 1)
      end

      changed = update_employer(employer, remote_group, matched_by:, source:, refreshed_at:)
      result.increment(
        processed_count: 1,
        matched_count: 1,
        updated_count: changed ? 1 : 0,
        unchanged_count: changed ? 0 : 1
      )
    end

    def update_employer(employer, remote_group, matched_by:, source:, refreshed_at:)
      settings = employer.settings.to_h.stringify_keys.merge(
        "vitable_care_group_remote_reference_id" => remote_reference_id(remote_group),
        "vitable_care_group_last_refreshed_at" => refreshed_at,
        "vitable_care_group_snapshot_source" => source,
        "vitable_care_group_snapshot_matched_by" => matched_by,
        SNAPSHOT_KEY => remote_group_summary(remote_group).merge(
          "matched_by" => matched_by,
          "source" => source,
          "refreshed_at" => refreshed_at
        )
      ).compact
      settings[CareGroupRepository::GROUP_ID_KEY] = remote_id(remote_group) if remote_id(remote_group).present?
      settings.delete(CONFLICT_KEY)

      employer.assign_attributes(settings:)
      changed = employer.has_changes_to_save?
      employer.save! if changed
      changed
    end

    def record_conflict(employer, remote_group, matched_by:, source:, refreshed_at:)
      employer.update!(
        settings: employer.settings.to_h.stringify_keys.merge(
          CONFLICT_KEY => {
            "local_group_id" => local_group_id(employer),
            "remote_group_id" => remote_id(remote_group),
            "remote_reference_id" => remote_reference_id(remote_group),
            "remote_name" => remote_group.fetch("name", nil),
            "matched_by" => matched_by,
            "source" => source,
            "refreshed_at" => refreshed_at
          }.compact
        )
      )
    end

    def employer_for_remote(remote_group)
      id = remote_id(remote_group)
      if id.present?
        employer = employer_scope.find { |record| local_group_id(record) == id }
        return [ employer, "care_group_id" ] if employer
      end

      employer = employer_from_reference_id(remote_reference_id(remote_group))
      return [ employer, "external_reference_id" ] if employer

      employer = employer_from_name(remote_group)
      return [ employer, "name" ] if employer

      [ nil, nil ]
    end

    def employer_from_reference_id(reference_id)
      value = reference_id.to_s
      return unless value.match?(/\Amusto_care_group_\d+\z/)

      employer_scope.find { |employer| employer.id == value.delete_prefix("musto_care_group_").to_i }
    end

    def employer_from_name(remote_group)
      name = normalize(remote_group.fetch("name", nil))
      return if name.blank?

      matches = employer_scope.select { |employer| normalize(employer.name) == name }
      matches.one? ? matches.first : nil
    end

    def remote_id_conflict?(employer, id)
      local_group_id(employer).present? && id.present? && local_group_id(employer) != id
    end

    def local_group_id(employer)
      employer.settings.to_h.stringify_keys.fetch(CareGroupRepository::GROUP_ID_KEY, nil).presence
    end

    def remote_id(remote_group)
      remote_group.fetch("id", nil).presence
    end

    def validate_remote_group_identity!(remote_group)
      reference = remote_reference_id(remote_group).presence || remote_group.fetch("name", nil).presence || "unknown group"
      raise ArgumentError, "Vitable API snapshot group #{reference} did not include a remote group ID" if remote_id(remote_group).blank?
    end

    def remote_reference_id(remote_group)
      remote_group.fetch("external_reference_id", nil).presence || remote_group.fetch("reference_id", nil).presence
    end

    def remote_group_summary(remote_group)
      remote_group.slice("id", "organization_id", "name", "external_reference_id", "created_at", "updated_at")
    end

    def normalize(value)
      value.to_s.strip.downcase.presence
    end

    def employer_scope
      @employer_scope ||= @connection.organization.employers.to_a
    end
  end
end
