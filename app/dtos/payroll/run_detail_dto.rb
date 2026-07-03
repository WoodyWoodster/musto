module Payroll
  RunDetailDto = Data.define(
    :id,
    :employer_id,
    :employer_name,
    :organization_name,
    :period_start_on,
    :period_end_on,
    :pay_date,
    :status,
    :gross_pay_cents,
    :total_adjustments_cents,
    :total_deductions_cents,
    :estimated_tax_cents,
    :estimated_net_pay_cents,
    :employee_count,
    :line_items,
    :deductions,
    :adjustments,
    :preflight_checks,
    :export_payload
  ) do
    def self.from_record(record)
      deductions = record.payroll_deductions.to_a
      adjustments = record.payroll_adjustments.to_a
      line_items = employee_lines(deductions, adjustments)
      total_adjustments_cents = adjustments.sum(&:amount_cents)
      total_deductions_cents = deductions.sum(&:amount_cents)
      estimated_tax_cents = (record.gross_pay_cents * 0.18).round

      new(
        id: record.id,
        employer_id: record.employer_id,
        employer_name: record.employer.name,
        organization_name: record.employer.organization.name,
        period_start_on: record.period_start_on,
        period_end_on: record.period_end_on,
        pay_date: record.pay_date,
        status: record.status,
        gross_pay_cents: record.gross_pay_cents,
        total_adjustments_cents:,
        total_deductions_cents:,
        estimated_tax_cents:,
        estimated_net_pay_cents: record.gross_pay_cents + total_adjustments_cents - total_deductions_cents - estimated_tax_cents,
        employee_count: line_items.count,
        line_items:,
        deductions: deductions.sort_by(&:created_at).reverse.map { |deduction| Operations::PayrollDeductionDto.from_record(deduction) },
        adjustments: adjustments.sort_by(&:created_at).reverse.map { |adjustment| Operations::PayrollAdjustmentDto.from_record(adjustment) },
        preflight_checks: preflight_checks(record, deductions, adjustments, line_items),
        export_payload: export_payload(record, deductions, adjustments)
      )
    end

    def finalized?
      status == "finalized"
    end

    def progress_percent
      finalized? ? 100 : 72
    end

    def self.employee_lines(deductions, adjustments)
      employees = (deductions.map(&:employee) + adjustments.map(&:employee)).uniq(&:id).sort_by(&:last_name)

      employees.map do |employee|
        employee_deductions = deductions.select { |deduction| deduction.employee_id == employee.id }
        employee_adjustments = adjustments.select { |adjustment| adjustment.employee_id == employee.id }
        gross_pay_cents = employee.compensation_cents / 24
        adjustments_cents = employee_adjustments.sum(&:amount_cents)
        deductions_cents = employee_deductions.sum(&:amount_cents)
        estimated_tax_cents = (gross_pay_cents * 0.18).round
        ready = employee_deductions.any? && employee_deductions.all? { |deduction| deduction.status == "ready" }

        RunEmployeeLineDto.new(
          employee_id: employee.id,
          employee_name: employee.full_name,
          title: employee.title,
          gross_pay_cents:,
          adjustments_cents:,
          deductions_cents:,
          estimated_tax_cents:,
          estimated_net_pay_cents: gross_pay_cents + adjustments_cents - deductions_cents - estimated_tax_cents,
          status: ready ? "ready" : "needs_review"
        )
      end
    end

    def self.preflight_checks(record, deductions, adjustments, line_items)
      waiting_count = deductions.count { |deduction| deduction.status == "waiting_on_enrollment" }
      ready_count = line_items.count { |line| line.status == "ready" }

      [
        RunPreflightCheckDto.new(
          label: "Employee payroll lines",
          status: line_items.any? ? "ready" : "needs_review",
          detail: "#{line_items.count} employees included in this run"
        ),
        RunPreflightCheckDto.new(
          label: "Vitable deductions",
          status: waiting_count.zero? ? "ready" : "needs_review",
          detail: waiting_count.zero? ? "All benefit deductions are ready" : "#{waiting_count} deductions waiting on enrollment"
        ),
        RunPreflightCheckDto.new(
          label: "Adjustment ledger",
          status: "ready",
          detail: "#{adjustments.count} one-time adjustments reviewed"
        ),
        RunPreflightCheckDto.new(
          label: "Export lock",
          status: record.status == "finalized" ? "finalized" : "estimated",
          detail: record.status == "finalized" ? "Run is locked for export" : "Finalize when operator review is complete"
        ),
        RunPreflightCheckDto.new(
          label: "Tax estimate",
          status: "ready",
          detail: "Estimated taxes calculated at 18% for prototype payroll modeling"
        )
      ]
    end

    def self.export_payload(record, deductions, adjustments)
      {
        payroll_run_id: record.id,
        employer_id: record.employer_id,
        period: {
          start_on: record.period_start_on.iso8601,
          end_on: record.period_end_on.iso8601,
          pay_date: record.pay_date.iso8601
        },
        status: record.status,
        deduction_count: deductions.count,
        adjustment_count: adjustments.count
      }
    end

    private_class_method :employee_lines, :preflight_checks, :export_payload
  end
end
