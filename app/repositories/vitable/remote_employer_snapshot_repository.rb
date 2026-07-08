module Vitable
  class RemoteEmployerSnapshotRepository < ApplicationRepository
    CONFLICT_KEY = "vitable_remote_employer_conflict"

    def initialize(connection:)
      @connection = connection
    end

    def reconcile_snapshot(remote_employers:, source:, refreshed_at: Time.current.iso8601)
      Array(remote_employers).reduce(RemoteEmployerSnapshotReconciliationDto.empty) do |result, remote_employer|
        reconcile_employer(
          result:,
          remote_employer: remote_employer.to_h.stringify_keys,
          source:,
          refreshed_at:
        )
      end
    end

    private

    def reconcile_employer(result:, remote_employer:, source:, refreshed_at:)
      dto = RemoteEmployerDto.from_hash(remote_employer).validate_identity!(response_label: "Vitable API snapshot employer")
      employer, matched_by = employer_for_remote(dto)
      return result.increment(processed_count: 1, unmatched_count: 1) unless employer

      if remote_id_conflict?(employer, dto.remote_employer_id)
        record_conflict(employer, remote_employer, matched_by:, source:, refreshed_at:)
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
      settings.delete(CONFLICT_KEY)

      attributes = {
        settings:
      }
      attributes[:vitable_id] = dto.remote_employer_id if employer.vitable_id.blank? && dto.remote_employer_id.present?

      employer.assign_attributes(attributes)
      changed = employer.has_changes_to_save?
      employer.save! if changed
      changed
    end

    def record_conflict(employer, remote_employer, matched_by:, source:, refreshed_at:)
      conflict = RemoteEmployerConflictDto.from_remote(
        employer:,
        remote_employer:,
        matched_by:,
        source:,
        refreshed_at:
      )

      employer.update!(
        settings: employer.settings.to_h.stringify_keys.merge(CONFLICT_KEY => conflict.to_metadata)
      )
    end

    def employer_for_remote(dto)
      id = dto.remote_employer_id
      if id.present?
        employer = employer_scope.find_by(vitable_id: id)
        return [ employer, "vitable_id" ] if employer
      end

      employer = employer_from_reference_id(dto.reference_id)
      return [ employer, "reference_id" ] if employer

      employer = employer_from_name(dto)
      return [ employer, "name" ] if employer

      [ nil, nil ]
    end

    def employer_from_reference_id(reference_id)
      value = reference_id.to_s
      return unless value.match?(/\Amusto_employer_\d+\z/)

      employer_scope.find_by(id: value.delete_prefix("musto_employer_").to_i)
    end

    def employer_from_name(dto)
      names = [
        dto.legal_name,
        dto.name
      ].filter_map { |value| value.to_s.strip.downcase.presence }.uniq
      return if names.empty?

      matches = employer_scope.select do |employer|
        [ employer.legal_name, employer.name ].filter_map { |value| value.to_s.strip.downcase.presence }.intersect?(names)
      end
      matches.one? ? matches.first : nil
    end

    def remote_id_conflict?(employer, id)
      employer.vitable_id.present? && id.present? && employer.vitable_id != id
    end

    def employer_scope
      @connection.organization.employers
    end
  end
end
