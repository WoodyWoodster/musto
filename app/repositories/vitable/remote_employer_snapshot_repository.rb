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
      validate_remote_employer_identity!(remote_employer)
      employer, matched_by = employer_for_remote(remote_employer)
      return result.increment(processed_count: 1, unmatched_count: 1) unless employer

      if remote_id_conflict?(employer, remote_id(remote_employer))
        record_conflict(employer, remote_employer, matched_by:, source:, refreshed_at:)
        return result.increment(processed_count: 1, conflict_count: 1)
      end

      changed = update_employer(employer, remote_employer, matched_by:, source:, refreshed_at:)
      result.increment(
        processed_count: 1,
        matched_count: 1,
        updated_count: changed ? 1 : 0,
        unchanged_count: changed ? 0 : 1
      )
    end

    def update_employer(employer, remote_employer, matched_by:, source:, refreshed_at:)
      settings = employer.settings.to_h.stringify_keys.merge(
        "vitable_remote_status" => remote_status(remote_employer),
        "vitable_remote_reference_id" => remote_reference_id(remote_employer),
        "vitable_remote_organization_id" => remote_employer.fetch("organization_id", nil),
        "vitable_last_refreshed_at" => refreshed_at,
        "vitable_last_snapshot_source" => source,
        "vitable_last_snapshot_matched_by" => matched_by,
        "vitable_remote_employer" => remote_employer_summary(remote_employer)
      ).compact
      settings.delete(CONFLICT_KEY)

      attributes = {
        settings:
      }
      attributes[:vitable_id] = remote_id(remote_employer) if employer.vitable_id.blank? && remote_id(remote_employer).present?

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

    def employer_for_remote(remote_employer)
      id = remote_id(remote_employer)
      if id.present?
        employer = employer_scope.find_by(vitable_id: id)
        return [ employer, "vitable_id" ] if employer
      end

      employer = employer_from_reference_id(remote_reference_id(remote_employer))
      return [ employer, "reference_id" ] if employer

      employer = employer_from_name(remote_employer)
      return [ employer, "name" ] if employer

      [ nil, nil ]
    end

    def employer_from_reference_id(reference_id)
      value = reference_id.to_s
      return unless value.match?(/\Amusto_employer_\d+\z/)

      employer_scope.find_by(id: value.delete_prefix("musto_employer_").to_i)
    end

    def employer_from_name(remote_employer)
      names = [
        remote_employer.fetch("legal_name", nil),
        remote_employer.fetch("name", nil)
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

    def remote_id(remote_employer)
      remote_employer.fetch("id", nil).presence
    end

    def validate_remote_employer_identity!(remote_employer)
      reference = remote_reference_id(remote_employer).presence || remote_employer.fetch("name", nil).presence || "unknown employer"
      raise ArgumentError, "Vitable API snapshot employer #{reference} did not include a remote employer ID" if remote_id(remote_employer).blank?
    end

    def remote_reference_id(remote_employer)
      remote_employer.fetch("reference_id", nil).presence || remote_employer.fetch("external_reference_id", nil).presence
    end

    def remote_status(remote_employer)
      return "active" if remote_employer.fetch("active", nil) == true
      return "inactive" if remote_employer.fetch("active", nil) == false

      remote_employer.fetch("status", nil)
    end

    def remote_employer_summary(remote_employer)
      remote_employer.slice("id", "organization_id", "name", "legal_name", "ein", "reference_id", "email", "phone_number", "active")
    end

    def employer_scope
      @connection.organization.employers
    end
  end
end
