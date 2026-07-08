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
      dto = RemoteGroupDto.from_hash(remote_group).validate_identity!(response_label: "Vitable API snapshot group")
      employer, matched_by = employer_for_remote(dto)
      return result.increment(processed_count: 1, unmatched_count: 1) unless employer

      if remote_id_conflict?(employer, dto.group_id)
        record_conflict(employer, dto, matched_by:, source:, refreshed_at:)
        return result.increment(processed_count: 1, conflict_count: 1)
      end

      changed = update_employer(employer, dto, matched_by:, source:, refreshed_at:)
      result.increment(
        processed_count: 1,
        matched_count: 1,
        updated_count: changed ? 1 : 0,
        unchanged_count: changed ? 0 : 1
      )
    end

    def update_employer(employer, dto, matched_by:, source:, refreshed_at:)
      settings = employer.settings.to_h.stringify_keys.merge(dto.settings_metadata(source:, refreshed_at:, matched_by:))
      settings[CareGroupRepository::GROUP_ID_KEY] = dto.group_id if dto.group_id.present?
      settings.delete(CONFLICT_KEY)

      employer.assign_attributes(settings:)
      changed = employer.has_changes_to_save?
      employer.save! if changed
      changed
    end

    def record_conflict(employer, dto, matched_by:, source:, refreshed_at:)
      employer.update!(
        settings: employer.settings.to_h.stringify_keys.merge(
          CONFLICT_KEY => {
            "local_group_id" => local_group_id(employer),
            "remote_group_id" => dto.group_id,
            "remote_reference_id" => dto.external_reference_id,
            "remote_name" => dto.name,
            "matched_by" => matched_by,
            "source" => source,
            "refreshed_at" => refreshed_at
          }.compact
        )
      )
    end

    def employer_for_remote(dto)
      id = dto.group_id
      if id.present?
        employer = employer_scope.find { |record| local_group_id(record) == id }
        return [ employer, "care_group_id" ] if employer
      end

      employer = employer_from_reference_id(dto.external_reference_id)
      return [ employer, "external_reference_id" ] if employer

      employer = employer_from_name(dto)
      return [ employer, "name" ] if employer

      [ nil, nil ]
    end

    def employer_from_reference_id(reference_id)
      value = reference_id.to_s
      return unless value.match?(/\Amusto_care_group_\d+\z/)

      employer_scope.find { |employer| employer.id == value.delete_prefix("musto_care_group_").to_i }
    end

    def employer_from_name(dto)
      name = normalize(dto.name)
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

    def normalize(value)
      value.to_s.strip.downcase.presence
    end

    def employer_scope
      @employer_scope ||= @connection.organization.employers.to_a
    end
  end
end
