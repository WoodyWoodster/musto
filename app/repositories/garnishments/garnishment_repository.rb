module Garnishments
  class GarnishmentRepository < ApplicationRepository
    PACKET_KEY = "garnishment_remittance_packet"
    GARNISHMENT_TYPES = %w[child_support tax_levy creditor_garnishment].freeze
    TAX_WITHHOLDING_RATE = 0.18
    DISPOSABLE_EARNINGS_CAP_RATE = 0.5

    def initialize(employer: nil)
      @employer = employer
    end

    def orders
      return EmployeeDeduction.none unless @employer

      @employer
        .employee_deductions
        .includes(employee: [ :department, :work_location ])
        .where(deduction_type: GARNISHMENT_TYPES)
        .current_first
    end

    def current_run
      return unless @employer

      @employer.payroll_runs.includes(:payroll_deductions).order(pay_date: :desc).first
    end

    def latest_packet
      @employer&.settings.to_h.fetch(PACKET_KEY, nil)
    end

    def issues
      run = current_run
      order_records = orders.to_a
      return [ empty_holdback("No garnishment orders are configured for this employer") ] if order_records.empty?
      return order_records.map { |order| holdback_line(order, amount_cents: 0, reason: "No current payroll run is available for garnishment remittance") } unless run

      order_records.flat_map { |order| holdbacks_for(order, run) }
    end

    def find_order(id)
      scope = EmployeeDeduction.includes(employee: [ :employer, :department, :work_location ]).where(deduction_type: GARNISHMENT_TYPES)
      scope = scope.where(employer_id: @employer.id) if @employer
      scope.find(id)
    end

    def approve_order(order, approved_by:)
      return false unless order.approvable?

      order.activate!(approved_by:)
    end

    def pause_order(order, paused_by:, reason:)
      return false unless order.pausable?

      order.pause!(paused_by:, reason:)
    end

    def generate_packet(requested_by:)
      run = current_run
      order_records = orders.to_a
      return store_packet(missing_run_packet(order_records, requested_by:)) unless run

      lines, holdbacks = build_lines(order_records, run)
      packet = packet_payload(run, order_records, lines, holdbacks, requested_by:)

      EmployeeDeduction.transaction do
        lines.each do |line|
          payroll_deduction = upsert_payroll_deduction(run, line)
          line["payroll_deduction_id"] = payroll_deduction.id
        end
        store_packet(packet)
      end

      packet
    end

    def gross_cents_for(order)
      order.employee.compensation_cents / 24
    end

    def disposable_earnings_cents_for(order)
      gross = gross_cents_for(order)
      [ gross - (gross * TAX_WITHHOLDING_RATE).round, 0 ].max
    end

    def estimated_amount_for(order, pay_date: current_run&.pay_date || Date.current)
      order.estimated_amount_for(gross_cents_for(order), pay_date:)
    end

    def readiness_status_for(order, run = current_run)
      return "needs_review" unless run
      return "blocked" if holdbacks_for(order, run).any?

      "ready"
    end

    def readiness_reason_for(order, run = current_run)
      return "No current payroll run is available" unless run

      holdback = holdbacks_for(order, run).first
      holdback.present? ? holdback.fetch("reason") : "Ready for agency remittance"
    end

    private

    def build_lines(order_records, run)
      lines = []
      holdbacks = []

      order_records.each do |order|
        order_holdbacks = holdbacks_for(order, run)
        if order_holdbacks.any?
          holdbacks.concat(order_holdbacks)
        else
          lines << packet_line(order, run, amount_cents: estimated_amount_for(order, pay_date: run.pay_date))
        end
      end

      holdbacks << empty_holdback("No garnishment orders are ready for remittance") if order_records.empty?
      [ lines, holdbacks ]
    end

    def holdbacks_for(order, run)
      amount_cents = estimated_amount_for(order, pay_date: run.pay_date)
      disposable_earnings_cents = disposable_earnings_cents_for(order)
      cap_cents = (disposable_earnings_cents * DISPOSABLE_EARNINGS_CAP_RATE).round
      holdbacks = []

      holdbacks << holdback_line(order, amount_cents:, reason: holdback_reason(order, run)) unless order.ready_for_payroll?(pay_date: run.pay_date)
      holdbacks << holdback_line(order, amount_cents:, reason: "Agency name is missing from the legal order") if order.agency_name.blank?
      holdbacks << holdback_line(order, amount_cents:, reason: "Agency case number is missing from the legal order") if order.case_number.blank?
      holdbacks << holdback_line(order, amount_cents:, reason: "Calculated withholding is zero for this payroll run") if amount_cents.zero? && order.active?
      holdbacks << holdback_line(order, amount_cents:, reason: "Withholding exceeds 50% of modeled disposable earnings") if amount_cents > cap_cents && cap_cents.positive?

      holdbacks
    end

    def upsert_payroll_deduction(run, line)
      deduction = run.payroll_deductions.find_or_initialize_by(employee_id: line.fetch("employee_id"), code: payroll_code(line.fetch("deduction_id")))
      deduction.assign_attributes(
        amount_cents: line.fetch("amount_cents"),
        status: "ready",
        metadata: deduction.metadata.to_h.merge(
          "source" => "garnishment_remittance_packet",
          "employee_deduction_id" => line.fetch("deduction_id"),
          "agency_name" => line.fetch("agency_name"),
          "case_number" => line.fetch("case_number"),
          "remittance_method" => line.fetch("remittance_method"),
          "generated_at" => Time.current.iso8601
        )
      )
      deduction.save!
      deduction
    end

    def packet_payload(run, order_records, lines, holdbacks, requested_by:)
      {
        "packet_id" => "garnishments_#{@employer.id}_#{run.id}_#{Time.current.to_i}",
        "generated_at" => Time.current.iso8601,
        "requested_by" => requested_by,
        "employer_id" => @employer.id,
        "payroll_run_id" => run.id,
        "pay_date" => run.pay_date.iso8601,
        "status" => lines.any? && holdbacks.empty? ? "ready" : "needs_review",
        "totals" => {
          "order_count" => order_records.count,
          "remittance_count" => lines.count,
          "agency_count" => lines.map { |line| line.fetch("agency_name") }.uniq.count,
          "holdback_count" => holdbacks.count,
          "total_withheld_cents" => lines.sum { |line| line.fetch("amount_cents") },
          "disposable_earnings_cents" => lines.sum { |line| line.fetch("disposable_earnings_cents") }
        },
        "agencies" => agency_summaries(lines),
        "lines" => lines,
        "holdbacks" => holdbacks
      }
    end

    def missing_run_packet(order_records, requested_by:)
      {
        "packet_id" => "garnishments_#{@employer.id}_missing_run_#{Time.current.to_i}",
        "generated_at" => Time.current.iso8601,
        "requested_by" => requested_by,
        "employer_id" => @employer.id,
        "payroll_run_id" => nil,
        "pay_date" => Date.current.iso8601,
        "status" => "needs_review",
        "totals" => {
          "order_count" => order_records.count,
          "remittance_count" => 0,
          "agency_count" => 0,
          "holdback_count" => [ order_records.count, 1 ].max,
          "total_withheld_cents" => 0,
          "disposable_earnings_cents" => 0
        },
        "agencies" => [],
        "lines" => [],
        "holdbacks" => order_records.any? ? order_records.map { |order| holdback_line(order, amount_cents: 0, reason: "No current payroll run is available for garnishment remittance") } : [ empty_holdback("No current payroll run is available for garnishment remittance") ]
      }
    end

    def store_packet(packet)
      @employer.update!(settings: @employer.settings.to_h.merge(PACKET_KEY => packet))
      packet
    end

    def packet_line(order, run, amount_cents:)
      {
        "deduction_id" => order.id,
        "payroll_deduction_id" => nil,
        "employee_id" => order.employee_id,
        "employee_name" => order.employee.full_name,
        "employee_title" => order.employee.title,
        "department_name" => order.employee.department&.name,
        "title" => order.title,
        "deduction_type" => order.deduction_type,
        "agency_name" => order.agency_name,
        "case_number" => order.case_number,
        "priority" => order.priority,
        "gross_cents" => gross_cents_for(order),
        "disposable_earnings_cents" => disposable_earnings_cents_for(order),
        "amount_cents" => amount_cents,
        "remittance_method" => remittance_method_for(order),
        "service_state" => service_state_for(order),
        "pay_date" => run.pay_date.iso8601,
        "due_on" => (run.pay_date + 3.days).iso8601,
        "status" => "withheld"
      }
    end

    def agency_summaries(lines)
      lines.group_by { |line| line.fetch("agency_name") }.map do |agency_name, agency_lines|
        {
          "agency_name" => agency_name,
          "service_state" => agency_lines.first.fetch("service_state"),
          "remittance_method" => agency_lines.first.fetch("remittance_method"),
          "line_count" => agency_lines.count,
          "employee_count" => agency_lines.map { |line| line.fetch("employee_id") }.uniq.count,
          "amount_cents" => agency_lines.sum { |line| line.fetch("amount_cents") }
        }
      end.sort_by { |agency| agency.fetch("agency_name").to_s }
    end

    def holdback_line(order, amount_cents:, reason:)
      {
        "deduction_id" => order.id,
        "employee_name" => order.employee.full_name,
        "title" => order.title,
        "deduction_type" => order.deduction_type,
        "agency_name" => order.agency_name,
        "case_number" => order.case_number,
        "amount_cents" => amount_cents,
        "status" => order.status,
        "reason" => reason
      }
    end

    def empty_holdback(reason)
      {
        "deduction_id" => nil,
        "employee_name" => "Garnishment program",
        "title" => "Agency remittance",
        "deduction_type" => "child_support",
        "agency_name" => nil,
        "case_number" => nil,
        "amount_cents" => 0,
        "status" => "needs_review",
        "reason" => reason
      }
    end

    def holdback_reason(order, run)
      return "Order starts after this payroll pay date" if order.starts_on > run.pay_date
      return "Order ended before this payroll pay date" if order.ends_on.present? && order.ends_on < run.pay_date
      return "Order balance is fully satisfied" if order.current_balance_cents.to_i.zero? && order.current_balance_cents.present?
      return "Order is pending payroll approval" if order.pending?
      return "Order is blocked pending legal or agency documentation" if order.blocked?
      return "Order is paused" if order.paused?
      return "Order is closed" if order.closed?

      "Order is not ready for payroll withholding"
    end

    def payroll_code(deduction_id)
      "EMPLOYEE_DEDUCTION_#{deduction_id}"
    end

    def remittance_method_for(order)
      order.metadata.to_h.fetch("remittance_method", "agency_ach")
    end

    def service_state_for(order)
      order.metadata.to_h.fetch("service_state", order.employee.work_location&.state.presence || "Federal")
    end
  end
end
