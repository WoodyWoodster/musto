module Taxes
  class CenterQuery
    def initialize(employer_repository: Employers::EmployerRepository.new)
      @employer = employer_repository.first_for_operations
      @repository = TaxRepository.new(employer: @employer)
    end

    def call
      employees = @repository.employees.to_a
      runs = @repository.payroll_runs.to_a
      locations = @repository.work_locations.to_a
      compliance_cases = @repository.compliance_cases.to_a
      agency_accounts = @repository.agency_accounts
      liabilities = runs.map { |run| payroll_liability(run) }
      jurisdictions = jurisdictions(locations, runs)
      packets = @repository.packets

      CenterDto.new(
        employer: Operations::EmployerContextDto.from_record(@employer),
        metrics: metrics(liabilities, agency_accounts, jurisdictions, compliance_cases),
        agency_accounts: agency_accounts.map { |account| agency_account(account) },
        filing_calendar: filing_calendar(agency_accounts),
        liabilities: liabilities,
        jurisdictions: jurisdictions,
        recommendations: recommendations(employees, runs, locations, compliance_cases),
        packets: packets.map { |payload| PacketDto.from_hash(payload) },
        packet_payload: packets.first
      )
    end

    private

    def metrics(liabilities, agency_accounts, jurisdictions, compliance_cases)
      open_tax_cases = compliance_cases.count { |item| item.status != "resolved" && item.kind.include?("tax") }
      jurisdiction_reviews = jurisdictions.count { |jurisdiction| jurisdiction.status != "ready" }
      total_liability_cents = liabilities.sum(&:total_liability_cents)

      [
        MetricDto.new(label: "Tax liability", value: total_liability_cents, hint: "#{liabilities.count} payroll runs", status: liabilities.any? ? "ready" : "needs_review", accent: "bg-indigo-500", format: "money"),
        MetricDto.new(label: "Agency accounts", value: agency_accounts.count, hint: "#{agency_accounts.count { |account| account.fetch('status') == 'ready' }} ready", status: agency_accounts.any? { |account| account.fetch("status") != "ready" } ? "needs_review" : "ready", accent: "bg-cyan-500", format: "number"),
        MetricDto.new(label: "Jurisdiction review", value: jurisdiction_reviews, hint: "#{jurisdictions.count} work locations", status: jurisdiction_reviews.positive? ? "needs_review" : "ready", accent: "bg-amber-500", format: "number"),
        MetricDto.new(label: "Open tax risk", value: open_tax_cases, hint: "compliance cases", status: open_tax_cases.positive? ? "needs_review" : "ready", accent: "bg-rose-500", format: "number")
      ]
    end

    def agency_account(account)
      attributes = account.stringify_keys

      AgencyAccountDto.new(
        key: attributes.fetch("key"),
        agency_name: attributes.fetch("agency_name"),
        jurisdiction: attributes.fetch("jurisdiction"),
        account_reference: attributes.fetch("account_reference"),
        deposit_schedule: attributes.fetch("deposit_schedule"),
        next_due_on: Date.iso8601(attributes.fetch("next_due_on")),
        liability_cents: attributes.fetch("liability_cents", 0),
        status: attributes.fetch("status"),
        detail: attributes.fetch("detail")
      )
    end

    def filing_calendar(agency_accounts)
      agency_accounts.map do |account|
        attributes = account.stringify_keys
        FilingCalendarItemDto.new(
          key: "filing_#{attributes.fetch('key')}",
          title: "#{attributes.fetch('jurisdiction')} payroll deposit",
          agency_name: attributes.fetch("agency_name"),
          jurisdiction: attributes.fetch("jurisdiction"),
          period_label: "#{Date.current.beginning_of_quarter.strftime('%b %-d')} - #{Date.current.end_of_quarter.strftime('%b %-d')}",
          due_on: Date.iso8601(attributes.fetch("next_due_on")),
          liability_cents: attributes.fetch("liability_cents", 0),
          deposit_schedule: attributes.fetch("deposit_schedule"),
          status: attributes.fetch("status")
        )
      end.sort_by(&:due_on)
    end

    def payroll_liability(run)
      employee_tax_cents = run.estimated_tax_cents
      employer_tax_cents = @repository.employer_tax_cents(run)
      adjustment_cents = run.total_adjustments_cents
      deduction_cents = run.total_deductions_cents

      PayrollLiabilityDto.new(
        payroll_run_id: run.id,
        period_label: "#{run.period_start_on.strftime('%b %-d')} - #{run.period_end_on.strftime('%b %-d')}",
        pay_date: run.pay_date,
        gross_pay_cents: run.gross_pay_cents,
        adjustment_cents: adjustment_cents,
        deduction_cents: deduction_cents,
        employee_tax_cents: employee_tax_cents,
        employer_tax_cents: employer_tax_cents,
        total_liability_cents: employee_tax_cents + employer_tax_cents,
        status: run.status == "finalized" ? "ready" : "needs_review"
      )
    end

    def jurisdictions(locations, runs)
      current_run = runs.first
      locations.map do |location|
        location_employees = location.employees.select { |employee| employee.employment_status == "active" }
        jurisdiction = location.state.presence || (location.remote? ? "Remote US" : location.country)
        registration_status = location.remote? && location.state.blank? ? "registration review" : "registered"
        current_run_payroll_cents = current_run.present? ? location_employees.sum(&:compensation_cents) / 24 : 0

        JurisdictionExposureDto.new(
          jurisdiction: jurisdiction,
          location_name: location.name,
          employee_count: location_employees.count,
          annual_payroll_cents: location_employees.sum(&:compensation_cents),
          current_run_payroll_cents: current_run_payroll_cents,
          remote: location.remote?,
          registration_status: registration_status,
          status: registration_status == "registered" ? "ready" : "needs_review"
        )
      end
    end

    def recommendations(employees, runs, locations, compliance_cases)
      routes = Rails.application.routes.url_helpers
      items = []
      missing_tax_docs = employees.select { |employee| employee.employee_documents.none? { |document| document.document_type == "tax" && document.status == "complete" } }
      open_tax_cases = compliance_cases.select { |item| item.status != "resolved" && item.kind.include?("tax") }
      remote_locations = locations.select { |location| location.remote? && location.state.blank? }
      unfinalized_runs = runs.select { |run| run.status != "finalized" }

      if @employer.ein.blank?
        items << RecommendationDto.new(key: "legal_entity", title: "Complete legal entity tax setup", detail: "Add an EIN before generating filing packets.", severity: "high", status: "blocked", owner: "Finance", action_path: routes.company_setup_path)
      end

      if missing_tax_docs.any?
        items << RecommendationDto.new(key: "employee_tax_docs", title: "Collect employee tax forms", detail: "#{missing_tax_docs.count} active employees are missing completed tax documents.", severity: "medium", status: "needs_review", owner: "People", action_path: routes.onboarding_path)
      end

      if open_tax_cases.any?
        items << RecommendationDto.new(key: "tax_cases", title: "Resolve tax compliance cases", detail: "#{open_tax_cases.count} open tax cases can affect agency registrations.", severity: "high", status: "needs_review", owner: "Compliance", action_path: routes.compliance_path)
      end

      if remote_locations.any?
        items << RecommendationDto.new(key: "remote_jurisdiction", title: "Confirm remote payroll jurisdictions", detail: "#{remote_locations.count} remote work locations need state-level registration review.", severity: "medium", status: "needs_review", owner: "Payroll", action_path: routes.workforce_path)
      end

      if unfinalized_runs.any?
        items << RecommendationDto.new(key: "payroll_finalization", title: "Finalize payroll runs before filing", detail: "#{unfinalized_runs.count} payroll runs are not finalized yet.", severity: "medium", status: "needs_review", owner: "Payroll", action_path: routes.payroll_path)
      end

      return items if items.any?

      [
        RecommendationDto.new(key: "tax_packet_ready", title: "Filing packet is ready", detail: "Payroll runs, tax documents, and agency accounts are aligned for review.", severity: "low", status: "ready", owner: "Finance", action_path: routes.generate_tax_filing_packet_path)
      ]
    end
  end
end
