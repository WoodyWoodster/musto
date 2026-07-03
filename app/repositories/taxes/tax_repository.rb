module Taxes
  class TaxRepository < ApplicationRepository
    EMPLOYER_TAX_ESTIMATE_RATE = 0.08

    def initialize(employer: nil)
      @employer = employer
    end

    def employees
      return Employee.none unless @employer

      @employer
        .employees
        .active
        .includes(:department, :work_location, :employee_documents, payroll_deductions: [ :payroll_run ])
        .order(:last_name, :first_name)
    end

    def payroll_runs
      return PayrollRun.none unless @employer

      @employer.payroll_runs.includes(:payroll_deductions, :payroll_adjustments).order(pay_date: :desc)
    end

    def work_locations
      return WorkLocation.none unless @employer

      @employer.work_locations.includes(:employees).order(:state, :name)
    end

    def compliance_cases
      return ComplianceCase.none unless @employer

      @employer.compliance_cases.includes(:employee).order(severity_sort, :due_on)
    end

    def packets
      payload = @employer&.settings.to_h.fetch("tax_filing_packet", nil)
      payload.present? ? [ payload ] : []
    end

    def agency_accounts
      saved_accounts = @employer&.settings.to_h.fetch("tax_agency_accounts", nil)
      return saved_accounts if saved_accounts.present?

      default_agency_accounts
    end

    def generate_filing_packet(requested_by:)
      runs = payroll_runs.to_a
      accounts = agency_accounts
      recommendations = packet_recommendations
      packet = {
        "packet_id" => "tax_filing_#{@employer.id}_#{Time.current.to_i}",
        "generated_at" => Time.current.iso8601,
        "requested_by" => requested_by,
        "employer_id" => @employer.id,
        "status" => recommendations.any? { |recommendation| recommendation.fetch("status") == "blocked" } ? "needs_review" : recommendations.any? ? "needs_review" : "ready",
        "totals" => {
          "payroll_run_count" => runs.count,
          "gross_pay_cents" => runs.sum(&:gross_pay_cents),
          "employee_tax_cents" => runs.sum(&:estimated_tax_cents),
          "employer_tax_cents" => runs.sum { |run| employer_tax_cents(run) },
          "total_liability_cents" => runs.sum { |run| run.estimated_tax_cents + employer_tax_cents(run) },
          "agency_account_count" => accounts.count
        },
        "agency_accounts" => accounts,
        "recommendations" => recommendations
      }

      @employer.update!(settings: @employer.settings.to_h.merge("tax_filing_packet" => packet))
      packet
    end

    def employer_tax_cents(run)
      (run.gross_pay_cents * EMPLOYER_TAX_ESTIMATE_RATE).round
    end

    private

    def default_agency_accounts
      accounts = [
        agency_account(
          key: "federal_irs",
          agency_name: "Federal payroll taxes",
          jurisdiction: "Federal",
          account_reference: @employer&.ein.presence || "EIN pending",
          deposit_schedule: setting_value("pay_frequency", "biweekly"),
          next_due_on: next_monthly_due_on,
          liability_cents: payroll_runs.sum { |run| run.estimated_tax_cents + employer_tax_cents(run) },
          status: @employer&.ein.present? ? "ready" : "blocked",
          detail: @employer&.ein.present? ? "EIN present for payroll deposits" : "Legal entity EIN must be configured"
        )
      ]

      state_locations.each do |state, locations|
        accounts << agency_account(
          key: "state_#{state.downcase}",
          agency_name: "#{state} withholding",
          jurisdiction: state,
          account_reference: "Registration review",
          deposit_schedule: "per payroll",
          next_due_on: next_quarter_due_on,
          liability_cents: state_liability_cents(locations),
          status: state_registration_status(state),
          detail: "#{locations.count} work location#{'s' unless locations.count == 1} in #{state}"
        )
      end

      if remote_locations.any?
        accounts << agency_account(
          key: "remote_multi_state",
          agency_name: "Remote worker review",
          jurisdiction: "Multi-state",
          account_reference: "Registration review",
          deposit_schedule: "manual review",
          next_due_on: next_quarter_due_on,
          liability_cents: remote_liability_cents,
          status: "needs_review",
          detail: "#{remote_locations.sum { |location| location.employees.active.count }} remote employees need jurisdiction confirmation"
        )
      end

      accounts
    end

    def agency_account(key:, agency_name:, jurisdiction:, account_reference:, deposit_schedule:, next_due_on:, liability_cents:, status:, detail:)
      {
        "key" => key,
        "agency_name" => agency_name,
        "jurisdiction" => jurisdiction,
        "account_reference" => account_reference,
        "deposit_schedule" => deposit_schedule,
        "next_due_on" => next_due_on.iso8601,
        "liability_cents" => liability_cents,
        "status" => status,
        "detail" => detail
      }
    end

    def packet_recommendations
      recommendations = []
      recommendations << packet_recommendation("legal_entity", "Complete legal entity tax setup", "Employer EIN is required before filing packets can be released.", "high", "blocked") if @employer&.ein.blank?

      open_tax_cases = compliance_cases.select { |item| item.status != "resolved" && item.kind.include?("tax") }
      recommendations << packet_recommendation("tax_cases", "Resolve open tax compliance cases", "#{open_tax_cases.count} payroll tax compliance cases need review.", "high", "needs_review") if open_tax_cases.any?

      incomplete_tax_documents = employees.select { |employee| employee.employee_documents.none? { |document| document.document_type == "tax" && document.status == "complete" } }
      recommendations << packet_recommendation("employee_tax_docs", "Collect employee tax forms", "#{incomplete_tax_documents.count} employees are missing completed tax documents.", "medium", "needs_review") if incomplete_tax_documents.any?

      recommendations << packet_recommendation("remote_jurisdiction", "Confirm remote worker jurisdictions", "#{remote_locations.count} remote work locations need payroll tax registration review.", "medium", "needs_review") if remote_locations.any?

      draft_runs = payroll_runs.select { |run| run.status != "finalized" }
      recommendations << packet_recommendation("payroll_finalization", "Finalize payroll runs before filing", "#{draft_runs.count} payroll runs are still #{draft_runs.first&.status || 'draft'} and should be locked before filing.", "medium", "needs_review") if draft_runs.any?

      recommendations
    end

    def packet_recommendation(key, title, detail, severity, status)
      {
        "key" => key,
        "title" => title,
        "detail" => detail,
        "severity" => severity,
        "status" => status
      }
    end

    def state_locations
      work_locations.select { |location| location.state.present? }.group_by(&:state)
    end

    def remote_locations
      work_locations.select(&:remote?)
    end

    def state_registration_status(state)
      open_case = compliance_cases.find { |item| item.status != "resolved" && item.kind.include?("tax") && item.description.to_s.include?(state) }
      open_case.present? ? "needs_review" : "ready"
    end

    def state_liability_cents(locations)
      employee_ids = locations.flat_map { |location| location.employees.active.map(&:id) }
      payroll_runs.sum do |run|
        run.payroll_deductions.select { |deduction| employee_ids.include?(deduction.employee_id) }.sum { run.estimated_tax_cents / [ run.payroll_deductions.count, 1 ].max }
      end
    end

    def remote_liability_cents
      state_liability_cents(remote_locations)
    end

    def next_monthly_due_on
      Date.current.next_month.change(day: 15)
    end

    def next_quarter_due_on
      (Date.current.end_of_quarter + 30.days)
    end

    def setting_value(key, fallback = nil)
      @employer&.settings.to_h.fetch(key, fallback)
    end
  end
end
