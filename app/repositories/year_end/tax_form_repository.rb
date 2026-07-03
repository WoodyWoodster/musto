module YearEnd
  class TaxFormRepository < ApplicationRepository
    PACKET_KEY = "year_end_tax_form_packet"
    CONTRACTOR_REPORTING_THRESHOLD_CENTS = 600_00

    def initialize(employer: nil, tax_year: Date.current.year)
      @employer = employer
      @tax_year = tax_year.to_i
    end

    attr_reader :tax_year

    def forms
      return YearEndTaxForm.none unless @employer

      @employer.year_end_tax_forms.includes(:employee, :contractor).for_year(@tax_year).due_first
    end

    def employees
      return Employee.none unless @employer

      @employer.employees.includes(:department, :work_location, :pay_statements, :employee_documents).order(:last_name, :first_name)
    end

    def contractors
      return Contractor.none unless @employer

      @employer.contractors.includes(:contractor_payments).order(:last_name, :first_name)
    end

    def latest_packet
      @employer&.settings.to_h.fetch(PACKET_KEY, nil)
    end

    def issues
      holdbacks_for(forms.to_a)
    end

    def find_form(id)
      forms.find(id)
    end

    def deliver_form(form, delivered_by:)
      form.update!(
        status: "delivered",
        delivered_at: Time.current,
        metadata: form.metadata.to_h.merge(
          "delivered_by" => delivered_by,
          "delivered_from" => "year_end_tax_forms_center",
          "delivered_at" => Time.current.iso8601
        )
      )
    end

    def generate_packet(requested_by:)
      generated_forms = generate_forms
      holdbacks = holdbacks_for(generated_forms)
      ready_forms = generated_forms.select { |form| form.status.in?(%w[ready filed delivered accepted]) }
      packet = {
        "packet_id" => "year_end_tax_forms_#{@employer.id}_#{@tax_year}_#{Time.current.to_i}",
        "generated_at" => Time.current.iso8601,
        "requested_by" => requested_by,
        "employer_id" => @employer.id,
        "tax_year" => @tax_year,
        "status" => holdbacks.any? ? "needs_review" : "ready",
        "totals" => {
          "form_count" => generated_forms.count,
          "w2_count" => generated_forms.count(&:employee_form?),
          "form_1099_count" => generated_forms.count(&:contractor_form?),
          "ready_count" => ready_forms.count,
          "holdback_count" => holdbacks.count,
          "gross_wages_cents" => generated_forms.sum(&:gross_wages_cents),
          "contractor_payment_cents" => generated_forms.sum(&:contractor_payment_cents),
          "withholding_cents" => generated_forms.sum { |form| form.federal_withholding_cents + form.state_withholding_cents }
        },
        "forms" => generated_forms.map { |form| packet_line(form) },
        "holdbacks" => holdbacks
      }

      @employer.update!(settings: @employer.settings.to_h.merge(PACKET_KEY => packet))
      packet
    end

    private

    def generate_forms
      employee_forms = employees.map { |employee| generate_employee_form(employee) }
      contractor_forms = contractors.map { |contractor| generate_contractor_form(contractor) }.compact

      (employee_forms + contractor_forms).sort_by { |form| [ form.form_type, form.recipient_name ] }
    end

    def generate_employee_form(employee)
      pay_statements = employee.pay_statements.select { |statement| statement.pay_date.year == @tax_year && !statement.void? }
      gross_wages_cents = pay_statements.sum(&:gross_pay_cents)
      federal_withholding_cents = pay_statements.sum(&:tax_cents)
      state_withholding_cents = (federal_withholding_cents * 0.18).round
      benefit_reportable_cents = pay_statements.sum(&:deduction_cents)
      form = YearEndTaxForm.find_or_initialize_by(employer: @employer, employee:, tax_year: @tax_year, form_type: "w2")
      form.assign_attributes(
        recipient_name: employee.full_name,
        recipient_email: employee.email,
        tin_last4: employee.metadata.to_h.fetch("ssn_last4", nil),
        jurisdiction: employee.work_location&.state.presence || "Federal",
        gross_wages_cents:,
        federal_withholding_cents:,
        state_withholding_cents:,
        benefit_reportable_cents:,
        contractor_payment_cents: 0,
        status: generated_status(employee, gross_wages_cents),
        delivery_method: employee.metadata.to_h.fetch("tax_form_delivery_method", "employee_portal"),
        consent_status: employee.metadata.to_h.fetch("tax_form_consent_status", "electronic_consented"),
        correction_status: form.correction_status.presence || "none",
        due_on: year_end_due_on,
        metadata: form.metadata.to_h.merge(
          "generated_from" => "year_end_tax_forms_center",
          "generated_at" => Time.current.iso8601,
          "pay_statement_count" => pay_statements.count
        )
      )
      form.save!
      form
    end

    def generate_contractor_form(contractor)
      payments = contractor.contractor_payments.select { |payment| payment.pay_date.year == @tax_year && payment.status.in?(%w[approved scheduled paid]) }
      payment_cents = payments.sum(&:amount_cents)
      return if payment_cents.zero?

      form = YearEndTaxForm.find_or_initialize_by(employer: @employer, contractor:, tax_year: @tax_year, form_type: "1099_nec")
      form.assign_attributes(
        recipient_name: contractor.display_name,
        recipient_email: contractor.email,
        tin_last4: contractor.metadata.to_h.fetch("tin_last4", nil),
        jurisdiction: "Federal",
        gross_wages_cents: 0,
        federal_withholding_cents: 0,
        state_withholding_cents: 0,
        benefit_reportable_cents: 0,
        contractor_payment_cents: payment_cents,
        status: generated_contractor_status(contractor, payment_cents),
        delivery_method: "contractor_portal",
        consent_status: contractor.metadata.to_h.fetch("tax_form_consent_status", "requested"),
        correction_status: form.correction_status.presence || "none",
        due_on: year_end_due_on,
        metadata: form.metadata.to_h.merge(
          "generated_from" => "year_end_tax_forms_center",
          "generated_at" => Time.current.iso8601,
          "payment_count" => payments.count
        )
      )
      form.save!
      form
    end

    def generated_status(employee, gross_wages_cents)
      return "correction_needed" if employee.metadata.to_h.fetch("tax_form_correction_needed", false)
      return "draft" if gross_wages_cents.zero?
      return "draft" if employee.employee_documents.none? { |document| document.document_type == "tax" && document.status == "complete" }

      "ready"
    end

    def generated_contractor_status(contractor, payment_cents)
      return "draft" if contractor.tax_form_status != "complete"
      return "draft" if payment_cents < CONTRACTOR_REPORTING_THRESHOLD_CENTS

      "ready"
    end

    def holdbacks_for(generated_forms)
      generated_forms.flat_map do |form|
        form.employee_form? ? employee_holdbacks(form) : contractor_holdbacks(form)
      end
    end

    def employee_holdbacks(form)
      holdbacks = []
      holdbacks << holdback(form, "missing_wages", "high", "blocked", "No pay statement wages were found for the tax year.") if form.gross_wages_cents.zero?
      holdbacks << holdback(form, "missing_tax_document", "medium", "needs_review", "Completed employee tax document is missing.") if form.employee&.employee_documents&.none? { |document| document.document_type == "tax" && document.status == "complete" }
      holdbacks << holdback(form, "missing_ssn_last4", "medium", "needs_review", "Recipient SSN last four is missing from metadata.") if form.tin_last4.blank?
      holdbacks << holdback(form, "correction_needed", "high", "correction_needed", "Tax form has a pending correction marker.") if form.correction_needed?
      holdbacks
    end

    def contractor_holdbacks(form)
      holdbacks = []
      holdbacks << holdback(form, "below_1099_threshold", "low", "skipped", "Contractor payments are below the 1099 reporting threshold.") if form.contractor_payment_cents < CONTRACTOR_REPORTING_THRESHOLD_CENTS
      holdbacks << holdback(form, "missing_w9", "high", "blocked", "Contractor W-9 or tax profile is incomplete.") if form.contractor&.tax_form_status != "complete"
      holdbacks << holdback(form, "missing_tin_last4", "medium", "needs_review", "Contractor TIN last four is missing from metadata.") if form.tin_last4.blank?
      holdbacks
    end

    def holdback(form, reason_code, severity, status, reason)
      {
        "form_id" => form.id,
        "recipient_name" => form.recipient_name,
        "form_type" => form.form_type,
        "tax_year" => form.tax_year,
        "severity" => severity,
        "status" => status,
        "reason_code" => reason_code,
        "reason" => reason,
        "amount_cents" => form.employee_form? ? form.gross_wages_cents : form.contractor_payment_cents
      }
    end

    def packet_line(form)
      {
        "form_id" => form.id,
        "employee_id" => form.employee_id,
        "contractor_id" => form.contractor_id,
        "recipient_name" => form.recipient_name,
        "recipient_email" => form.recipient_email,
        "form_type" => form.form_type,
        "tax_year" => form.tax_year,
        "tin_last4" => form.tin_last4,
        "jurisdiction" => form.jurisdiction,
        "gross_wages_cents" => form.gross_wages_cents,
        "federal_withholding_cents" => form.federal_withholding_cents,
        "state_withholding_cents" => form.state_withholding_cents,
        "benefit_reportable_cents" => form.benefit_reportable_cents,
        "contractor_payment_cents" => form.contractor_payment_cents,
        "status" => form.status,
        "delivery_method" => form.delivery_method,
        "consent_status" => form.consent_status,
        "correction_status" => form.correction_status,
        "due_on" => form.due_on.iso8601,
        "delivered_at" => form.delivered_at&.iso8601,
        "accepted_at" => form.accepted_at&.iso8601
      }
    end

    def year_end_due_on
      Date.new(@tax_year + 1, 1, 31)
    end
  end
end
