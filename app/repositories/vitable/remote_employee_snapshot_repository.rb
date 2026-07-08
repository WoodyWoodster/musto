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
      dto = RemoteEmployeeDto.from_hash(remote_employee).validate_identity!(response_label: "Vitable API snapshot employee")
      employee = employee_for_remote(employer, dto)
      return result.increment(processed_count: 1, unmatched_count: 1) unless employee

      changed = update_employee(employee, dto, source:, refreshed_at:)
      deduction_sync = PayrollDeductionRepository.new.sync_employee_deductions(
        employee:,
        remote_deductions: dto.deductions,
        source:,
        reconciled_at: refreshed_at
      )
      dependent_sync = dependent_snapshot_repository.sync_remote_employee_dependents(
        employee:,
        remote_employee: dto.raw_payload,
        source:,
        refreshed_at:
      )
      lifecycle_reconciliation = deactivate_employee_benefits(employee, dto, source:, refreshed_at:)

      result.increment(
        processed_count: 1,
        matched_count: 1,
        updated_count: changed ? 1 : 0,
        unchanged_count: changed ? 0 : 1,
        **dependent_sync.to_reconciliation_attributes,
        deduction_sync:,
        lifecycle_reconciliation:
      )
    end

    def update_employee(employee, dto, source:, refreshed_at:)
      attributes = {
        metadata: employee.metadata.to_h.stringify_keys.merge(dto.metadata(source:, refreshed_at:))
      }
      local_employment_status = dto.local_employment_status
      attributes[:employment_status] = local_employment_status if local_employment_status.present? && employee.employment_status != local_employment_status
      attributes[:start_on] = dto.hire_date if dto.hire_date.present? && employee.start_on != dto.hire_date
      attributes[:vitable_id] = dto.remote_employee_id if dto.remote_employee_id.present? && employee.vitable_id != dto.remote_employee_id
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

    def employee_for_remote(employer, dto)
      remote_employee_id = dto.remote_employee_id
      employee = employer.employees.find_by(vitable_id: remote_employee_id) if remote_employee_id.present?
      return employee if employee

      reference_id = dto.reference_id.to_s
      if reference_id.match?(/\Amusto_employee_\d+\z/)
        employee = employer.employees.find_by(id: reference_id.delete_prefix("musto_employee_").to_i)
        return employee if employee
      end

      email = dto.email.to_s.downcase
      employer.employees.detect { |employee_record| employee_record.email.to_s.downcase == email } if email.present?
    end

    def deactivate_employee_benefits(employee, dto, source:, refreshed_at:)
      return EmployeeLifecycleReconciliationDto.empty unless dto.local_employment_status == "terminated"

      EmployeeEligibilityRepository.new.deactivate_benefits!(
        employee:,
        source:,
        reconciled_at: refreshed_at
      )
    end

    def dependent_snapshot_repository
      @dependent_snapshot_repository ||= DependentSnapshotRepository.new
    end

    def employer_from_reference_id(reference_id)
      value = reference_id.to_s
      return unless value.match?(/\Amusto_employer_\d+\z/)

      employer_scope.find_by(id: value.delete_prefix("musto_employer_").to_i)
    end

    def employer_scope
      @connection.organization.employers
    end
  end
end
