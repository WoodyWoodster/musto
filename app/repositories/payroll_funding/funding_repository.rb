module PayrollFunding
  class FundingRepository < ApplicationRepository
    def initialize(employer: nil)
      @employer = employer
    end

    def employer_accounts
      return EmployerBankAccount.none unless @employer

      @employer.employer_bank_accounts.order(primary_account: :desc, created_at: :asc)
    end

    def employee_accounts
      return EmployeeBankAccount.none unless @employer

      EmployeeBankAccount
        .joins(:employee)
        .where(employees: { employer_id: @employer.id })
        .includes(employee: [ :department, :work_location ])
        .order(status: :asc, created_at: :asc)
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
      payload = @employer&.settings.to_h.fetch("payroll_funding_batch", nil)
      payload.present? ? [ payload ] : []
    end

    def find_employee_account(id)
      EmployeeBankAccount.includes(employee: [ :department, :work_location ]).find(id)
    end

    def verify_employee_account(account, reviewed_by:)
      return false if account.blocked?

      account.verify!(reviewed_by:)
    end

    def generate_batch(requested_by:)
      run = current_run
      return empty_batch(requested_by:) unless run

      payroll_detail = Payroll::RunDetailDto.from_record(run)
      funding_account = employer_accounts.verified.primary_accounts.first || employer_accounts.verified.first
      credits, holdbacks = ach_lines(payroll_detail, funding_account)
      batch = batch_payload(run, funding_account, credits, holdbacks, requested_by:)

      @employer.update!(settings: @employer.settings.to_h.merge("payroll_funding_batch" => batch))
      batch
    end

    private

    def ach_lines(payroll_detail, funding_account)
      accounts_by_employee = employee_accounts.to_a.group_by(&:employee_id)
      credits = []
      holdbacks = []

      payroll_detail.line_items.each do |line|
        account = accounts_by_employee.fetch(line.employee_id, []).find(&:ready_for_deposit?)
        if funding_account.blank?
          holdbacks << holdback_line(line, reason: "Employer funding account is not verified")
        elsif account.blank?
          holdbacks << holdback_line(line, reason: "Employee direct deposit account is not verified")
        elsif line.estimated_net_pay_cents <= 0
          holdbacks << holdback_line(line, reason: "Net pay must be positive for ACH credit")
        else
          credits << credit_line(line, account)
        end
      end

      [ credits, holdbacks ]
    end

    def batch_payload(run, funding_account, credits, holdbacks, requested_by:)
      {
        "batch_id" => "payroll_ach_#{@employer.id}_#{run.id}_#{Time.current.to_i}",
        "generated_at" => Time.current.iso8601,
        "requested_by" => requested_by,
        "payroll_run_id" => run.id,
        "employer_id" => @employer.id,
        "pay_date" => run.pay_date.iso8601,
        "status" => credits.any? && holdbacks.empty? ? "ready" : "needs_review",
        "debit" => funding_account.present? ? debit_line(funding_account, credits) : {},
        "totals" => {
          "credit_count" => credits.count,
          "employee_count" => credits.map { |line| line.fetch("employee_id") }.uniq.count,
          "holdback_count" => holdbacks.count,
          "total_cents" => credits.sum { |line| line.fetch("amount_cents") }
        },
        "credits" => credits,
        "holdbacks" => holdbacks
      }
    end

    def empty_batch(requested_by:)
      {
        "batch_id" => "payroll_ach_#{@employer.id}_missing_run_#{Time.current.to_i}",
        "generated_at" => Time.current.iso8601,
        "requested_by" => requested_by,
        "payroll_run_id" => nil,
        "employer_id" => @employer.id,
        "pay_date" => Date.current.iso8601,
        "status" => "needs_review",
        "debit" => {},
        "totals" => { "credit_count" => 0, "employee_count" => 0, "holdback_count" => 1, "total_cents" => 0 },
        "credits" => [],
        "holdbacks" => [
          {
            "employee_id" => nil,
            "employee_name" => "Payroll run",
            "amount_cents" => 0,
            "reason" => "No current payroll run is available for funding",
            "status" => "needs_review"
          }
        ]
      }
    end

    def credit_line(line, account)
      {
        "employee_id" => line.employee_id,
        "employee_name" => line.employee_name,
        "employee_account_id" => account.id,
        "institution_name" => account.institution_name,
        "account_last4" => account.account_last4,
        "amount_cents" => line.estimated_net_pay_cents,
        "trace_code" => "ACH#{line.employee_id.to_s.rjust(6, "0")}#{account.account_last4}"
      }
    end

    def holdback_line(line, reason:)
      {
        "employee_id" => line.employee_id,
        "employee_name" => line.employee_name,
        "amount_cents" => line.estimated_net_pay_cents,
        "reason" => reason,
        "status" => "needs_review"
      }
    end

    def debit_line(account, credits)
      {
        "employer_account_id" => account.id,
        "account_name" => account.name,
        "institution_name" => account.institution_name,
        "account_last4" => account.account_last4,
        "amount_cents" => credits.sum { |line| line.fetch("amount_cents") }
      }
    end
  end
end
