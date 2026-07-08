module Vitable
  class PayrollDeductionRepository < ApplicationRepository
    def sync_employee_deductions(employee:, remote_deductions:, source:, source_event: nil, reconciled_at: Time.current.iso8601)
      result = PayrollDeductionSyncResultDto.empty
      deductions = Array(remote_deductions)
      return result if deductions.empty?

      deductions.each do |payload|
        dto = RemotePayrollDeductionDto.from_hash(payload)
        payroll_run = payroll_run_for(employee.employer, dto)
        enrollment = enrollment_for_remote_deduction(employee, dto)
        deduction = payroll_deduction_for(payroll_run, employee, dto, enrollment:)
        attributes = deduction_attributes(
          deduction:,
          employee:,
          enrollment:,
          dto:,
          source:,
          source_event:,
          reconciled_at:
        )

        result = if deduction
          update_deduction(result, deduction, attributes)
        else
          created = payroll_run.payroll_deductions.create!(attributes)
          result.class.new(
            created_ids: result.created_ids + [ created.id ],
            updated_ids: result.updated_ids,
            unchanged_ids: result.unchanged_ids
          )
        end
      end

      result
    end

    private

    def update_deduction(result, deduction, attributes)
      if deduction_changes?(deduction, attributes)
        deduction.update!(attributes)
        result.class.new(
          created_ids: result.created_ids,
          updated_ids: result.updated_ids + [ deduction.id ],
          unchanged_ids: result.unchanged_ids
        )
      else
        result.class.new(
          created_ids: result.created_ids,
          updated_ids: result.updated_ids,
          unchanged_ids: result.unchanged_ids + [ deduction.id ]
        )
      end
    end

    def deduction_attributes(deduction:, employee:, enrollment:, dto:, source:, source_event:, reconciled_at:)
      {
        employee:,
        enrollment: enrollment || deduction&.enrollment,
        code: dto.payroll_code,
        amount_cents: dto.amount_cents,
        status: dto.payroll_status,
        vitable_id: dto.remote_id.presence || deduction&.vitable_id,
        metadata: deduction&.metadata.to_h.stringify_keys.merge(dto.metadata).merge(
          "source" => source,
          "last_reconciled_at" => reconciled_at,
          "last_webhook_event_id" => source_event&.event_id,
          "last_webhook_event_name" => source_event&.event_name
        ).compact
      }.compact
    end

    def payroll_deduction_for(payroll_run, employee, dto, enrollment:)
      if dto.remote_id.present?
        deduction = payroll_run.payroll_deductions.find_by(vitable_id: dto.remote_id)
        return deduction if deduction
      end

      if enrollment && dto.remote_id.blank?
        deduction = payroll_run.payroll_deductions.find_by(employee:, enrollment:)
        return deduction if deduction
      end

      payroll_run.payroll_deductions.find_by(employee:, code: dto.payroll_code)
    end

    def deduction_changes?(deduction, attributes)
      attributes.any? do |key, value|
        next false if key == :metadata

        deduction.public_send(key) != value
      end || deduction.metadata.to_h.stringify_keys != attributes.fetch(:metadata, {})
    end

    def enrollment_for_remote_deduction(employee, dto)
      enrollment_by_remote_deduction(employee, dto) ||
        enrollment_by_remote_deduction_plan(employee, dto) ||
        enrollment_by_deduction_name(employee, dto)
    end

    def enrollment_by_remote_deduction(employee, dto)
      enrollment_id = dto.raw_payload.fetch("enrollment_id", nil).presence
      return if enrollment_id.blank?

      employee.enrollments.find_by(vitable_id: enrollment_id)
    end

    def enrollment_by_remote_deduction_plan(employee, dto)
      plan_id = dto.raw_payload.fetch("plan_id", nil).presence ||
        dto.raw_payload.fetch("product_id", nil).presence ||
        dto.raw_payload.dig("benefit", "id").presence ||
        dto.raw_payload.dig("plan", "id").presence
      return if plan_id.blank?

      employee.enrollments.joins(:benefit_plan).find_by(benefit_plans: { vitable_id: plan_id })
    end

    def enrollment_by_deduction_name(employee, dto)
      return if dto.benefit_name.blank?

      employee.enrollments.includes(:benefit_plan).detect do |enrollment|
        enrollment.benefit_plan.name.casecmp?(dto.benefit_name.to_s)
      end
    end

    def current_or_create_payroll_run(employer)
      employer.payroll_runs.order(pay_date: :desc).first ||
        employer.payroll_runs.create!(
          period_start_on: Date.current.beginning_of_month,
          period_end_on: Date.current.end_of_month,
          pay_date: Date.current.end_of_month,
          gross_pay_cents: 0,
          status: "estimated"
        )
    end

    def payroll_run_for(employer, dto)
      return current_or_create_payroll_run(employer) if dto.period_start_on.blank? || dto.period_end_on.blank?

      employer.payroll_runs.find_or_create_by!(
        period_start_on: dto.period_start_on,
        period_end_on: dto.period_end_on
      ) do |run|
        run.pay_date = dto.period_end_on
        run.gross_pay_cents = 0
        run.status = "estimated"
      end
    end
  end
end
