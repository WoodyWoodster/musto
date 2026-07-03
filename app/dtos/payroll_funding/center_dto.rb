module PayrollFunding
  CenterDto = Data.define(
    :employer,
    :metrics,
    :employer_accounts,
    :employee_accounts,
    :payroll_run,
    :funding_issues,
    :batches,
    :batch_credits,
    :batch_holdbacks,
    :batch_payload
  ) do
    def generated?
      batch_payload.present?
    end

    def latest_batch
      batches.first
    end

    def primary_funding_account
      employer_accounts.find(&:primary_account)
    end

    def pending_accounts
      employee_accounts.select(&:reviewable?)
    end

    def verified_accounts
      employee_accounts.select(&:verified?)
    end
  end
end
