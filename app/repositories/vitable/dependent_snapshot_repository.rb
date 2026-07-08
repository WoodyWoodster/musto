module Vitable
  class DependentSnapshotRepository < ApplicationRepository
    def sync_remote_employee_dependents(employee:, remote_employee:, source:, refreshed_at:)
      remote_employee = normalized_payload(remote_employee)

      sync_employee_dependents(
        employee:,
        remote_dependents: remote_dependents_for(remote_employee),
        source:,
        refreshed_at:,
        remote_employee_id: remote_employee.fetch("id", nil)
      )
    end

    def sync_employee_dependents(employee:, remote_dependents:, source:, refreshed_at:, remote_employee_id: nil)
      normalized_dependents(remote_dependents, remote_employee_id:).reduce(DependentSnapshotSyncResultDto.empty) do |result, payload|
        sync_dependent(result.record_processed, employee, payload, source:, refreshed_at:)
      end
    end

    private

    def sync_dependent(result, employee, payload, source:, refreshed_at:)
      dto = RemoteDependentDto.from_hash(payload)
      dependent = dependent_for_remote(employee, dto)
      return result.record_missing_required if dto.missing_required_fields(existing: dependent).any?

      attributes = dto.attributes(existing: dependent, source:, refreshed_at:)
      if dependent
        update_dependent(result, dependent, attributes)
      else
        created = employee.dependents.create!(attributes)
        result.record_created(created.id)
      end
    end

    def update_dependent(result, dependent, attributes)
      dependent.assign_attributes(attributes)
      if dependent.has_changes_to_save?
        dependent.save!
        result.record_updated(dependent.id)
      else
        result.record_unchanged(dependent.id)
      end
    end

    def remote_dependents_for(remote_employee)
      dependents = remote_employee.fetch("dependents", nil)
      dependents = remote_employee.dig("member", "dependents") if dependents.blank?
      dependents
    end

    def normalized_dependents(remote_dependents, remote_employee_id:)
      if remote_dependents.is_a?(Hash)
        remote_dependents = [ remote_dependents ]
      elsif remote_dependents.respond_to?(:to_h) && !remote_dependents.respond_to?(:map)
        remote_dependents = [ remote_dependents.to_h ]
      end
      return [] unless remote_dependents.respond_to?(:map)

      remote_dependents.map do |dependent|
        normalized_payload(dependent).tap do |record|
          record["employee_id"] ||= remote_employee_id
        end
      end
    end

    def normalized_payload(payload)
      payload.respond_to?(:to_h) ? payload.to_h.stringify_keys : {}
    end

    def dependent_for_remote(employee, dto)
      if dto.remote_id.present?
        dependent = employee.dependents.find_by(vitable_id: dto.remote_id)
        return dependent if dependent
      end

      dependent = dependent_from_reference_id(employee, dto.reference_id)
      return dependent if dependent

      dependent_from_identity(employee, dto)
    end

    def dependent_from_reference_id(employee, reference_id)
      value = reference_id.to_s
      return unless value.match?(/\Amusto_dependent_\d+\z/)

      employee.dependents.find_by(id: value.delete_prefix("musto_dependent_").to_i)
    end

    def dependent_from_identity(employee, dto)
      identity_key = dto.identity_key
      return unless identity_key

      matches = employee.dependents.select do |dependent|
        [
          dependent.first_name.to_s.downcase,
          dependent.last_name.to_s.downcase,
          dependent.relationship,
          dependent.date_of_birth
        ] == identity_key
      end
      matches.one? ? matches.first : nil
    end
  end
end
