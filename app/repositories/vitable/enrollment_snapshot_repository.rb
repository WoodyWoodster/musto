module Vitable
  class EnrollmentSnapshotRepository < ApplicationRepository
    def initialize(connection:)
      @connection = connection
    end

    def reconcile_snapshot(snapshot_entries:, source:, refreshed_at: Time.current.iso8601)
      snapshot_entries.reduce(EnrollmentSnapshotReconciliationDto.empty) do |result, entry|
        reconcile_employee_entry(
          result:,
          entry: entry.to_h.stringify_keys,
          source:,
          refreshed_at:
        )
      end
    end

    private

    def reconcile_employee_entry(result:, entry:, source:, refreshed_at:)
      employee = employee_for_entry(entry)
      return result.increment(unmatched_count: 1) unless employee

      entry.fetch("enrollments", []).reduce(result) do |entry_result, payload|
        dto = RemoteEnrollmentDto.from_hash(payload)
        validate_remote_enrollment_identity!(dto)
        reconcile_enrollment(
          result: entry_result.increment(processed_count: 1),
          employee:,
          dto:,
          source:,
          refreshed_at:
        )
      end
    end

    def reconcile_enrollment(result:, employee:, dto:, source:, refreshed_at:)
      enrollment = enrollment_for(employee, dto)
      plan = enrollment&.benefit_plan || plan_for(employee.employer, dto)
      return result.increment(missing_plan_count: 1) unless enrollment || plan

      enrollment ||= employee.enrollments.build(benefit_plan: plan)
      was_new = enrollment.new_record?
      assign_enrollment_attributes(enrollment, dto, source:, refreshed_at:)

      if was_new
        enrollment.save!
        return result.increment(
          matched_count: 1,
          created_count: 1,
          deduction_sync: sync_payroll_deduction(enrollment, dto, source:, refreshed_at:)
        )
      end

      if enrollment.has_changes_to_save?
        enrollment.save!
        return result.increment(
          matched_count: 1,
          updated_count: 1,
          deduction_sync: sync_payroll_deduction(enrollment, dto, source:, refreshed_at:)
        )
      end

      result.increment(
        matched_count: 1,
        unchanged_count: 1,
        deduction_sync: sync_payroll_deduction(enrollment, dto, source:, refreshed_at:)
      )
    end

    def assign_enrollment_attributes(enrollment, dto, source:, refreshed_at:)
      attributes = {
        vitable_id: dto.remote_id,
        metadata: enrollment.metadata.to_h.stringify_keys.merge(dto.metadata).merge(
          "source" => source,
          "vitable_last_refreshed_at" => refreshed_at
        )
      }.compact

      if dto.local_status.present?
        attributes[:status] = dto.local_status
        attributes[:accepted_at] = dto.accepted? ? (dto.answered_at || enrollment.accepted_at || Time.current) : nil
      end
      attributes[:effective_on] = dto.coverage_start_on if dto.coverage_start_on.present?

      enrollment.assign_attributes(attributes)
    end

    def sync_payroll_deduction(enrollment, dto, source:, refreshed_at:)
      return PayrollDeductionSyncResultDto.empty unless dto.active_deduction? || enrollment.payroll_deductions.exists?

      PayrollDeductionRepository.new.sync_employee_deductions(
        employee: enrollment.employee,
        remote_deductions: [ dto.deduction_payload(enrollment) ],
        source:,
        reconciled_at: refreshed_at
      )
    end

    def employee_for_entry(entry)
      employee_id = entry.fetch("local_employee_id", nil)
      employee = employee_scope.find_by(id: employee_id) if employee_id.present?
      return employee if employee

      remote_employee_id = entry.fetch("remote_employee_id", nil)
      employee_scope.find_by(vitable_id: remote_employee_id) if remote_employee_id.present?
    end

    def enrollment_for(employee, dto)
      if dto.remote_id.present?
        enrollment = employee.enrollments.find_by(vitable_id: dto.remote_id)
        return enrollment if enrollment
      end

      plan = plan_for(employee.employer, dto)
      return employee.enrollments.find_by(benefit_plan: plan) if plan

      enrollment_by_benefit_name(employee, dto.benefit_name)
    end

    def enrollment_by_benefit_name(employee, benefit_name)
      return if benefit_name.blank?

      employee.enrollments.includes(:benefit_plan).detect do |enrollment|
        enrollment.benefit_plan.name.casecmp?(benefit_name.to_s)
      end
    end

    def plan_for(employer, dto)
      if dto.remote_plan_id.present?
        plan = employer.benefit_plans.find_by(vitable_id: dto.remote_plan_id)
        return plan if plan
      end

      return if dto.benefit_name.blank?

      employer.benefit_plans.detect { |plan| plan.name.casecmp?(dto.benefit_name.to_s) }
    end

    def validate_remote_enrollment_identity!(dto)
      reference = dto.raw_payload.fetch("id", nil).presence || dto.raw_payload.fetch("enrollment_id", nil).presence || "unknown enrollment"
      raise ArgumentError, "Vitable API snapshot enrollment #{reference} did not include a remote enrollment ID" if dto.raw_payload.fetch("id", nil).blank?
      raise ArgumentError, "Vitable API snapshot enrollment #{reference} did not include a remote employee ID" if dto.raw_payload.fetch("employee_id", nil).blank?
      raise ArgumentError, "Vitable API snapshot enrollment #{reference} did not include a remote benefit ID" if dto.raw_payload.dig("benefit", "id").blank?
    end

    def employee_scope
      Employee.joins(employer: :organization).where(employers: { organization_id: @connection.organization_id })
    end
  end
end
