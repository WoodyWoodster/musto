module Benefits
  ReconciliationItemDto = Data.define(
    :enrollment_id,
    :deduction_id,
    :employee_id,
    :employee_name,
    :plan_name,
    :enrollment_status,
    :coverage_level,
    :effective_on,
    :expected_amount_cents,
    :actual_amount_cents,
    :amount_delta_cents,
    :expected_status,
    :actual_status,
    :issue,
    :status,
    :severity
  ) do
    def self.from_record(record)
      deduction = current_deduction(record)
      expected_amount = expected_amount_cents(record)
      actual_amount = deduction&.amount_cents.to_i
      expected_status = expected_status(record)
      actual_status = deduction&.status || "missing"
      issue = issue_for(deduction, expected_amount, actual_amount, expected_status, actual_status)

      new(
        enrollment_id: record.id,
        deduction_id: deduction&.id,
        employee_id: record.employee_id,
        employee_name: record.employee.full_name,
        plan_name: record.benefit_plan.name,
        enrollment_status: record.status,
        coverage_level: record.coverage_level,
        effective_on: record.effective_on,
        expected_amount_cents: expected_amount,
        actual_amount_cents: actual_amount,
        amount_delta_cents: actual_amount - expected_amount,
        expected_status:,
        actual_status:,
        issue:,
        status: issue == "Aligned" ? "ready" : "needs_review",
        severity: severity_for(issue, record.status)
      )
    end

    def exception?
      status != "ready"
    end

    def aligned?
      !exception?
    end

    def self.current_deduction(record)
      record.payroll_deductions.max_by { |deduction| deduction.payroll_run&.pay_date || Date.new(1900, 1, 1) }
    end

    def self.expected_amount_cents(record)
      record.status == "accepted" ? record.benefit_plan.monthly_premium_cents : 0
    end

    def self.expected_status(record)
      case record.status
      when "accepted" then "ready"
      when "waived" then "waived"
      else "waiting_on_enrollment"
      end
    end

    def self.issue_for(deduction, expected_amount, actual_amount, expected_status, actual_status)
      return "Missing payroll deduction" unless deduction
      return "Amount and status mismatch" if expected_amount != actual_amount && expected_status != actual_status
      return "Amount mismatch" if expected_amount != actual_amount
      return "Status mismatch" if expected_status != actual_status

      "Aligned"
    end

    def self.severity_for(issue, enrollment_status)
      return "ready" if issue == "Aligned"
      return "blocked" if issue == "Missing payroll deduction"
      return "high" if enrollment_status == "accepted"

      "needs_review"
    end

    private_class_method :current_deduction, :expected_amount_cents, :expected_status, :issue_for, :severity_for
  end
end
