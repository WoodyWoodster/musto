module Benefits
  class BillingRepository < ApplicationRepository
    def initialize(employer: nil)
      @employer = employer
    end

    def invoices
      return BenefitInvoice.none unless @employer

      @employer
        .benefit_invoices
        .includes(benefit_invoice_lines: [ :employee, :benefit_plan, :enrollment ])
        .recent_first
    end

    def invoice_lines
      return BenefitInvoiceLine.none unless @employer

      BenefitInvoiceLine
        .joins(benefit_invoice: :employer)
        .where(benefit_invoices: { employer_id: @employer.id })
        .includes(:benefit_invoice, :employee, :benefit_plan, :enrollment)
        .order(BenefitInvoice.arel_table[:period_end_on].desc, BenefitInvoiceLine.arel_table[:status].asc)
    end

    def accepted_enrollments
      return Enrollment.none unless @employer

      Enrollment
        .accepted
        .joins(:employee)
        .where(employees: { employer_id: @employer.id })
        .includes(:benefit_plan, :payroll_deductions, employee: [ :department, :work_location ])
    end

    def current_payroll_run
      return unless @employer

      @employer.payroll_runs.includes(:payroll_deductions).order(pay_date: :desc).first
    end

    def packets
      payload = @employer&.settings.to_h.fetch("benefit_billing_packet", nil)
      payload.present? ? [ payload ] : []
    end

    def find_invoice(id)
      BenefitInvoice.includes(benefit_invoice_lines: [ :employee, :benefit_plan, :enrollment ]).find(id)
    end

    def approve_invoice(invoice, reviewed_by:)
      invoice.approve!(reviewed_by:)
    end

    def generate_packet(requested_by:)
      invoice = latest_or_create_invoice
      reconcile_invoice!(invoice)

      lines = invoice.benefit_invoice_lines.includes(:employee, :benefit_plan, :enrollment).to_a
      payments, holdbacks = lines.partition { |line| line.status == "matched" }
      packet = packet_payload(invoice, payments, holdbacks, requested_by:)

      @employer.update!(settings: @employer.settings.to_h.merge("benefit_billing_packet" => packet))
      packet
    end

    def latest_or_create_invoice
      invoices.first || create_invoice_from_enrollments
    end

    def reconcile_invoice!(invoice)
      invoice.benefit_invoice_lines.includes(:enrollment, :benefit_plan).find_each do |line|
        deduction_cents = payroll_deduction_amount(line.enrollment)
        expected_premium_cents = line.benefit_plan.monthly_premium_cents
        variance_cents = line.amount_cents - expected_premium_cents
        status = line_status(line, deduction_cents:, variance_cents:)
        employee_contribution_cents = [ deduction_cents, line.amount_cents ].min

        line.update!(
          expected_premium_cents:,
          expected_payroll_deduction_cents: deduction_cents,
          employee_contribution_cents:,
          employer_contribution_cents: line.amount_cents - employee_contribution_cents,
          variance_cents:,
          status:
        )
      end

      refresh_invoice_totals(invoice.reload)
    end

    private

    def create_invoice_from_enrollments
      period_start_on = Date.current.beginning_of_month
      period_end_on = Date.current.end_of_month
      invoice = @employer.benefit_invoices.create!(
        invoice_number: "VIT-#{@employer.id}-#{period_start_on.strftime("%Y%m")}",
        carrier: "Vitable",
        period_start_on:,
        period_end_on:,
        due_on: period_end_on + 10.days,
        status: "draft",
        metadata: { "source" => "generated_from_enrollments" }
      )

      accepted_enrollments.each do |enrollment|
        premium_cents = enrollment.benefit_plan.monthly_premium_cents
        deduction_cents = payroll_deduction_amount(enrollment)
        employee_contribution_cents = [ deduction_cents, premium_cents ].min

        invoice.benefit_invoice_lines.create!(
          employee: enrollment.employee,
          benefit_plan: enrollment.benefit_plan,
          enrollment:,
          coverage_level: enrollment.coverage_level,
          amount_cents: premium_cents,
          expected_premium_cents: premium_cents,
          expected_payroll_deduction_cents: deduction_cents,
          employee_contribution_cents:,
          employer_contribution_cents: premium_cents - employee_contribution_cents,
          variance_cents: 0,
          status: deduction_cents.positive? ? "matched" : "missing_deduction",
          metadata: { "source" => "generated_from_enrollments" }
        )
      end

      refresh_invoice_totals(invoice)
    end

    def payroll_deduction_amount(enrollment)
      return 0 unless enrollment

      run = current_payroll_run
      deduction = enrollment.payroll_deductions.find { |record| record.payroll_run_id == run&.id && record.status == "ready" }
      deduction&.amount_cents.to_i
    end

    def line_status(line, deduction_cents:, variance_cents:)
      return "variance" if variance_cents != 0
      return "missing_deduction" if line.enrollment&.status == "accepted" && deduction_cents.zero?
      return "needs_review" unless line.enrollment&.status == "accepted"

      "matched"
    end

    def refresh_invoice_totals(invoice)
      lines = invoice.benefit_invoice_lines.to_a
      variance_cents = lines.sum(&:variance_cents)

      invoice.update!(
        total_premium_cents: lines.sum(&:amount_cents),
        employee_contribution_cents: lines.sum(&:employee_contribution_cents),
        employer_contribution_cents: lines.sum(&:employer_contribution_cents),
        variance_cents:,
        status: invoice_status(invoice, lines, variance_cents)
      )
      invoice
    end

    def invoice_status(invoice, lines, variance_cents)
      return invoice.status if invoice.paid?
      return invoice.status if invoice.approved? && variance_cents.zero?
      return "needs_review" if lines.any?(&:blocked?) || variance_cents != 0

      "draft"
    end

    def packet_payload(invoice, payments, holdbacks, requested_by:)
      {
        "packet_id" => "benefit_billing_#{@employer.id}_#{invoice.id}_#{Time.current.to_i}",
        "generated_at" => Time.current.iso8601,
        "requested_by" => requested_by,
        "employer_id" => @employer.id,
        "invoice_id" => invoice.id,
        "invoice_number" => invoice.invoice_number,
        "carrier" => invoice.carrier,
        "status" => holdbacks.any? ? "needs_review" : "ready",
        "totals" => {
          "payment_count" => payments.count,
          "holdback_count" => holdbacks.count,
          "total_cents" => payments.sum(&:amount_cents)
        },
        "payments" => payments.map { |line| payment_line(line) },
        "holdbacks" => holdbacks.map { |line| holdback_line(line) }
      }
    end

    def payment_line(line)
      {
        "invoice_line_id" => line.id,
        "employee_id" => line.employee_id,
        "employee_name" => line.employee.full_name,
        "plan_name" => line.benefit_plan.name,
        "amount_cents" => line.amount_cents,
        "employee_contribution_cents" => line.employee_contribution_cents,
        "employer_contribution_cents" => line.employer_contribution_cents,
        "status" => line.status
      }
    end

    def holdback_line(line)
      {
        "invoice_line_id" => line.id,
        "employee_id" => line.employee_id,
        "employee_name" => line.employee.full_name,
        "plan_name" => line.benefit_plan.name,
        "amount_cents" => line.amount_cents,
        "reason" => holdback_reason(line),
        "status" => line.status
      }
    end

    def holdback_reason(line)
      return "Vitable invoice premium differs from the local plan premium by #{line.variance_cents} cents" if line.variance_cents != 0
      return "No ready payroll deduction is attached to the accepted enrollment" if line.status == "missing_deduction"

      "Enrollment is not ready for billing payment"
    end
  end
end
