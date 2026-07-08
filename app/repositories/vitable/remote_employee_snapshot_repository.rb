module Vitable
  class RemoteEmployeeSnapshotRepository < ApplicationRepository
    def initialize(connection:)
      @connection = connection
    end

    def reconcile_snapshot(snapshot_entries:, source:, refreshed_at: Time.current.iso8601)
      snapshot_entries.reduce(RemoteEmployeeSnapshotReconciliationDto.empty) do |result, entry|
        reconcile_employer_entry(
          result:,
          entry: entry.to_h.stringify_keys,
          source:,
          refreshed_at:
        )
      end
    end

    private

    def reconcile_employer_entry(result:, entry:, source:, refreshed_at:)
      remote_employees = entry.fetch("employees", []).map { |employee| employee.to_h.stringify_keys }
      employer = employer_for_entry(entry)
      return result.increment(processed_count: remote_employees.count, unmatched_employer_count: 1) unless employer

      remote_employees.reduce(result) do |entry_result, remote_employee|
        reconcile_employee(
          result: entry_result,
          employer:,
          remote_employee:,
          source:,
          refreshed_at:
        )
      end
    end

    def reconcile_employee(result:, employer:, remote_employee:, source:, refreshed_at:)
      validate_remote_employee_identity!(remote_employee)
      employee = employee_for_remote(employer, remote_employee)
      return result.increment(processed_count: 1, unmatched_count: 1) unless employee

      changed = update_employee(employee, remote_employee, source:, refreshed_at:)
      deduction_sync = PayrollDeductionRepository.new.sync_employee_deductions(
        employee:,
        remote_deductions: remote_employee.fetch("deductions", []),
        source:,
        reconciled_at: refreshed_at
      )
      dependent_sync = sync_dependents(employee, remote_employee, source:, refreshed_at:)
      lifecycle_reconciliation = deactivate_employee_benefits(employee, remote_employee, source:, refreshed_at:)

      result.increment(
        processed_count: 1,
        matched_count: 1,
        updated_count: changed ? 1 : 0,
        unchanged_count: changed ? 0 : 1,
        **dependent_sync,
        deduction_sync:,
        lifecycle_reconciliation:
      )
    end

    def update_employee(employee, remote_employee, source:, refreshed_at:)
      remote_employee_id = remote_employee.fetch("id")
      attributes = {
        metadata: employee.metadata.to_h.stringify_keys.merge(
          "vitable_remote_status" => remote_employee.fetch("status", nil),
          "vitable_member_id" => remote_employee.fetch("member_id", nil),
          "vitable_remote_reference_id" => remote_employee.fetch("reference_id", nil),
          "vitable_remote_deductions" => remote_employee.fetch("deductions", []),
          "vitable_last_refreshed_at" => refreshed_at,
          "vitable_last_snapshot_source" => source,
          "vitable_last_resource_snapshot" => remote_employee_summary(remote_employee)
        ).compact
      }
      local_employment_status = employee_employment_status_for(remote_employee)
      attributes[:employment_status] = local_employment_status if local_employment_status.present? && employee.employment_status != local_employment_status
      attributes[:vitable_id] = remote_employee_id if remote_employee_id.present? && employee.vitable_id != remote_employee_id
      employee.assign_attributes(attributes)
      changed = employee.has_changes_to_save?
      employee.save! if changed
      changed
    end

    def employer_for_entry(entry)
      local_employer_id = entry.fetch("local_employer_id", nil)
      employer = employer_scope.find_by(id: local_employer_id) if local_employer_id.present?
      return employer if employer

      remote_employer_id = entry.fetch("remote_employer_id", nil).presence || entry.fetch("id", nil).presence
      employer = employer_scope.find_by(vitable_id: remote_employer_id) if remote_employer_id.present?
      return employer if employer

      reference_id = entry.fetch("reference_id", nil).presence || entry.fetch("external_reference_id", nil).presence
      employer_from_reference_id(reference_id)
    end

    def employee_for_remote(employer, remote_employee)
      remote_employee_id = remote_employee.fetch("id", nil).presence
      employee = employer.employees.find_by(vitable_id: remote_employee_id) if remote_employee_id.present?
      return employee if employee

      reference_id = remote_employee.fetch("reference_id", nil).to_s
      if reference_id.match?(/\Amusto_employee_\d+\z/)
        employee = employer.employees.find_by(id: reference_id.delete_prefix("musto_employee_").to_i)
        return employee if employee
      end

      email = remote_employee.fetch("email", nil).to_s.downcase
      employer.employees.detect { |employee_record| employee_record.email.to_s.downcase == email } if email.present?
    end

    def employee_employment_status_for(remote_employee)
      normalized = remote_employee.fetch("status", nil).to_s.downcase
      return "terminated" if normalized.in?(%w[inactive deactivated terminated])
      return "active" if normalized.in?(%w[active reactivated])

      nil
    end

    def deactivate_employee_benefits(employee, remote_employee, source:, refreshed_at:)
      return EmployeeLifecycleReconciliationDto.empty unless employee_employment_status_for(remote_employee) == "terminated"

      EmployeeEligibilityRepository.new.deactivate_benefits!(
        employee:,
        source:,
        reconciled_at: refreshed_at
      )
    end

    def sync_dependents(employee, remote_employee, source:, refreshed_at:)
      remote_dependents_for(remote_employee).reduce(dependent_sync_counts) do |counts, payload|
        counts[:dependent_processed_count] += 1
        dto = RemoteDependentDto.from_hash(payload)
        dependent = dependent_for_remote(employee, dto)
        missing_fields = dto.missing_required_fields(existing: dependent)
        if missing_fields.any?
          counts[:dependent_missing_required_count] += 1
          next counts
        end

        attributes = dto.attributes(existing: dependent, source:, refreshed_at:)
        counts[:dependent_matched_count] += 1
        if dependent
          dependent.assign_attributes(attributes)
          if dependent.has_changes_to_save?
            dependent.save!
            counts[:dependent_updated_count] += 1
          else
            counts[:dependent_unchanged_count] += 1
          end
        else
          employee.dependents.create!(attributes)
          counts[:dependent_created_count] += 1
        end
        counts
      end
    end

    def dependent_sync_counts
      {
        dependent_processed_count: 0,
        dependent_matched_count: 0,
        dependent_created_count: 0,
        dependent_updated_count: 0,
        dependent_unchanged_count: 0,
        dependent_missing_required_count: 0
      }
    end

    def remote_dependents_for(remote_employee)
      dependents = remote_employee.fetch("dependents", nil)
      dependents = remote_employee.dig("member", "dependents") if dependents.blank?
      return [] unless dependents.respond_to?(:map)

      dependents.map do |dependent|
        dependent.to_h.stringify_keys.tap do |record|
          record["employee_id"] ||= remote_employee.fetch("id", nil)
        end
      end
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

    def employer_from_reference_id(reference_id)
      value = reference_id.to_s
      return unless value.match?(/\Amusto_employer_\d+\z/)

      employer_scope.find_by(id: value.delete_prefix("musto_employer_").to_i)
    end

    def employer_scope
      @connection.organization.employers
    end

    def remote_employee_summary(remote_employee)
      remote_employee.slice("id", "reference_id", "email", "status", "member_id")
    end

    def validate_remote_employee_identity!(remote_employee)
      reference = remote_employee.fetch("reference_id", nil).presence || remote_employee.fetch("email", nil).presence || "unknown remote employee"
      raise ArgumentError, "Vitable API snapshot employee #{reference} did not include a remote employee ID" if remote_employee.fetch("id", nil).blank?
      raise ArgumentError, "Vitable API snapshot employee #{reference} did not include a remote member ID" if remote_employee.fetch("member_id", nil).blank?
    end
  end
end
