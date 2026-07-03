module Deductions
  class DeductionRepository < ApplicationRepository
    def initialize(employer: nil)
      @employer = employer
    end

    def deductions
      return EmployeeDeduction.none unless @employer

      @employer
        .employee_deductions
        .includes(employee: [ :department, :work_location ])
        .current_first
    end

    def current_run
      return unless @employer

      @employer
        .payroll_runs
        .includes(:payroll_deductions, :payroll_adjustments, employer: :organization)
        .order(pay_date: :desc)
        .first
    end

    def batches
      payload = @employer&.settings.to_h.fetch("employee_deductions_packet", nil)
      payload.present? ? [ payload ] : []
    end

    def find_deduction(id)
      scope = EmployeeDeduction.includes(employee: [ :employer, :department, :work_location ])
      scope = scope.where(employer_id: @employer.id) if @employer
      scope.find(id)
    end

    def approve_deduction(deduction, approved_by:)
      return false unless deduction.approvable?

      deduction.activate!(approved_by:)
    end

    def pause_deduction(deduction, paused_by:, reason:)
      return false unless deduction.pausable?

      deduction.pause!(paused_by:, reason:)
    end

    def generate_packet(requested_by:)
      run = current_run
      return empty_packet(requested_by:) unless run

      lines, holdbacks = build_lines(run)
      packet = packet_payload(run, lines, holdbacks, requested_by:)

      EmployeeDeduction.transaction do
        lines.each do |line|
          payroll_deduction = upsert_payroll_deduction(run, line)
          line["payroll_deduction_id"] = payroll_deduction.id
        end
        @employer.update!(settings: @employer.settings.to_h.merge("employee_deductions_packet" => packet))
      end

      packet
    end

    private

    def build_lines(run)
      lines = []
      holdbacks = []

      deductions.to_a.each do |deduction|
        gross_cents = deduction.employee.compensation_cents / 24
        amount_cents = deduction.estimated_amount_for(gross_cents, pay_date: run.pay_date)

        if !deduction.ready_for_payroll?(pay_date: run.pay_date)
          holdbacks << holdback_line(deduction, amount_cents:, reason: holdback_reason(deduction, run))
        elsif amount_cents <= 0
          holdbacks << holdback_line(deduction, amount_cents:, reason: "Deduction amount is zero for this payroll run")
        else
          lines << packet_line(deduction, amount_cents:)
        end
      end

      holdbacks << empty_holdback("No recurring deductions are ready for this payroll run") if lines.empty?
      [ lines, holdbacks ]
    end

    def upsert_payroll_deduction(run, line)
      code = "EMPLOYEE_DEDUCTION_#{line.fetch("deduction_id")}"
      deduction = run.payroll_deductions.find_or_initialize_by(employee_id: line.fetch("employee_id"), code:)
      deduction.assign_attributes(
        amount_cents: line.fetch("amount_cents"),
        status: "ready",
        metadata: deduction.metadata.to_h.merge(
          "source" => "employee_deductions_packet",
          "employee_deduction_id" => line.fetch("deduction_id"),
          "deduction_type" => line.fetch("deduction_type"),
          "agency_name" => line.fetch("agency_name"),
          "case_number" => line.fetch("case_number"),
          "generated_at" => Time.current.iso8601
        )
      )
      deduction.save!
      deduction
    end

    def packet_payload(run, lines, holdbacks, requested_by:)
      {
        "batch_id" => "employee_deductions_#{@employer.id}_#{run.id}_#{Time.current.to_i}",
        "generated_at" => Time.current.iso8601,
        "requested_by" => requested_by,
        "payroll_run_id" => run.id,
        "employer_id" => @employer.id,
        "pay_date" => run.pay_date.iso8601,
        "status" => lines.any? && holdbacks.empty? ? "ready" : "needs_review",
        "totals" => {
          "line_count" => lines.count,
          "employee_count" => lines.map { |line| line.fetch("employee_id") }.uniq.count,
          "holdback_count" => holdbacks.count,
          "total_cents" => lines.sum { |line| line.fetch("amount_cents") }
        },
        "lines" => lines,
        "holdbacks" => holdbacks
      }
    end

    def empty_packet(requested_by:)
      {
        "batch_id" => "employee_deductions_#{@employer.id}_missing_run_#{Time.current.to_i}",
        "generated_at" => Time.current.iso8601,
        "requested_by" => requested_by,
        "payroll_run_id" => nil,
        "employer_id" => @employer.id,
        "pay_date" => Date.current.iso8601,
        "status" => "needs_review",
        "totals" => { "line_count" => 0, "employee_count" => 0, "holdback_count" => 1, "total_cents" => 0 },
        "lines" => [],
        "holdbacks" => [
          empty_holdback("No current payroll run is available for deductions")
        ]
      }
    end

    def packet_line(deduction, amount_cents:)
      {
        "deduction_id" => deduction.id,
        "payroll_deduction_id" => nil,
        "employee_id" => deduction.employee_id,
        "employee_name" => deduction.employee.full_name,
        "title" => deduction.title,
        "deduction_type" => deduction.deduction_type,
        "amount_cents" => amount_cents,
        "priority" => deduction.priority,
        "pre_tax" => deduction.pre_tax?,
        "agency_name" => deduction.agency_name,
        "case_number" => deduction.case_number,
        "status" => "withheld"
      }
    end

    def holdback_line(deduction, amount_cents:, reason:)
      {
        "deduction_id" => deduction.id,
        "employee_name" => deduction.employee.full_name,
        "title" => deduction.title,
        "deduction_type" => deduction.deduction_type,
        "amount_cents" => amount_cents,
        "status" => deduction.status,
        "reason" => reason
      }
    end

    def empty_holdback(reason)
      {
        "deduction_id" => nil,
        "employee_name" => "Payroll deductions",
        "title" => "Recurring deductions",
        "deduction_type" => "other",
        "amount_cents" => 0,
        "status" => "needs_review",
        "reason" => reason
      }
    end

    def holdback_reason(deduction, run)
      return "Deduction starts after this payroll pay date" if deduction.starts_on > run.pay_date
      return "Deduction ended before this payroll pay date" if deduction.ends_on.present? && deduction.ends_on < run.pay_date
      return "Deduction balance is fully satisfied" if deduction.current_balance_cents.to_i.zero? && deduction.current_balance_cents.present?
      return "Deduction is pending approval" if deduction.pending?
      return "Deduction is blocked pending documentation" if deduction.blocked?
      return "Deduction is paused" if deduction.paused?
      return "Deduction is closed" if deduction.closed?

      "Deduction is not ready for payroll"
    end
  end
end
