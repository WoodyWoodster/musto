module PayrollFunding
  class CenterQuery
    def initialize(employer_repository: Employers::EmployerRepository.new)
      @employer = employer_repository.first_for_operations
      @repository = FundingRepository.new(employer: @employer)
    end

    def call
      employer_accounts = @repository.employer_accounts.to_a
      employee_accounts = @repository.employee_accounts.to_a
      payroll_detail = payroll_detail_for(@repository.current_run)
      batches = @repository.batches
      latest_batch = batches.first.to_h

      CenterDto.new(
        employer: Operations::EmployerContextDto.from_record(@employer),
        metrics: metrics(employer_accounts, employee_accounts, payroll_detail),
        employer_accounts: employer_accounts.map { |account| EmployerAccountDto.from_record(account) },
        employee_accounts: employee_accounts.map { |account| EmployeeAccountDto.from_record(account) },
        payroll_run: RunFundingDto.from_payroll_detail(payroll_detail),
        funding_issues: funding_issues(employer_accounts, employee_accounts, payroll_detail),
        batches: batches.map { |payload| BatchDto.from_hash(payload) },
        batch_credits: latest_batch.fetch("credits", []).map { |payload| BatchCreditDto.from_hash(payload) },
        batch_holdbacks: latest_batch.fetch("holdbacks", []).map { |payload| BatchHoldbackDto.from_hash(payload) },
        batch_payload: batches.first
      )
    end

    private

    def payroll_detail_for(run)
      Payroll::RunDetailDto.from_record(run) if run
    end

    def metrics(employer_accounts, employee_accounts, payroll_detail)
      verified_employee_count = employee_accounts.count(&:verified?)
      pending_count = employee_accounts.count { |account| account.pending_verification? || account.prenote_sent? }
      funding_ready = employer_accounts.any?(&:ready_for_funding?)
      net_pay_cents = payroll_detail&.estimated_net_pay_cents.to_i

      [
        MetricDto.new(label: "Funding source", value: funding_ready ? 1 : 0, hint: funding_ready ? "verified employer bank ready" : "employer bank needs verification", status: funding_ready ? "ready" : "needs_review", accent: "bg-emerald-500", format: "number"),
        MetricDto.new(label: "Verified accounts", value: verified_employee_count, hint: "#{employee_accounts.count} direct deposit records", status: verified_employee_count == employee_accounts.count && employee_accounts.any? ? "ready" : "needs_review", accent: "bg-sky-500", format: "number"),
        MetricDto.new(label: "Pending verification", value: pending_count, hint: "prenotes or microdeposits need review", status: pending_count.positive? ? "needs_review" : "ready", accent: "bg-amber-500", format: "number"),
        MetricDto.new(label: "Net pay exposure", value: net_pay_cents, hint: payroll_detail ? "current run ACH amount" : "no current payroll run", status: payroll_detail ? "ready" : "blocked", accent: "bg-indigo-500", format: "money")
      ]
    end

    def funding_issues(employer_accounts, employee_accounts, payroll_detail)
      routes = Rails.application.routes.url_helpers
      items = []
      missing_funding = employer_accounts.none?(&:ready_for_funding?)
      pending_accounts = employee_accounts.select { |account| account.pending_verification? || account.prenote_sent? }
      blocked_accounts = employee_accounts.select(&:blocked?)

      if payroll_detail.blank?
        items << FundingIssueDto.new(key: "missing_payroll_run", title: "Create a payroll run", detail: "A payroll run is required before ACH credits can be generated.", severity: "high", status: "blocked", owner: "Payroll", count: 1, amount_cents: 0, action_path: routes.payroll_path)
      end

      if missing_funding
        items << FundingIssueDto.new(key: "funding_source", title: "Verify employer funding account", detail: "No verified company bank account is available to debit for payroll funding.", severity: "critical", status: "blocked", owner: "Finance", count: employer_accounts.count, amount_cents: payroll_detail&.estimated_net_pay_cents.to_i, action_path: routes.payroll_funding_path)
      end

      if pending_accounts.any?
        items << FundingIssueDto.new(key: "employee_prenotes", title: "Clear employee bank verification", detail: "#{pending_accounts.count} employee accounts are waiting on prenote or microdeposit review.", severity: "medium", status: "needs_review", owner: "People Ops", count: pending_accounts.count, amount_cents: 0, action_path: routes.payroll_funding_path)
      end

      if blocked_accounts.any?
        items << FundingIssueDto.new(key: "blocked_accounts", title: "Resolve blocked direct deposit accounts", detail: "#{blocked_accounts.count} accounts are blocked and will be held out of ACH credit generation.", severity: "high", status: "blocked", owner: "Payroll", count: blocked_accounts.count, amount_cents: 0, action_path: routes.payroll_funding_path)
      end

      return items if items.any?

      [
        FundingIssueDto.new(key: "funding_ready", title: "Payroll funding is batch-ready", detail: "Employer funding and employee direct deposit accounts are verified for the current run.", severity: "low", status: "ready", owner: "Payroll", count: employee_accounts.count, amount_cents: payroll_detail&.estimated_net_pay_cents.to_i, action_path: routes.generate_payroll_funding_batch_path)
      ]
    end
  end
end
