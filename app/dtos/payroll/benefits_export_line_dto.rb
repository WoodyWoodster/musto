module Payroll
  BenefitsExportLineDto = Data.define(
    :deduction_id,
    :employee_id,
    :employee_name,
    :code,
    :plan_name,
    :coverage_level,
    :enrollment_status,
    :deduction_status,
    :amount_cents,
    :included,
    :issue
  ) do
    def self.from_record(record)
      included = record.status == "ready" && record.amount_cents.positive?

      new(
        deduction_id: record.id,
        employee_id: record.employee_id,
        employee_name: record.employee.full_name,
        code: record.code,
        plan_name: record.enrollment&.benefit_plan&.name || "Pending enrollment",
        coverage_level: record.enrollment&.coverage_level || "unknown",
        enrollment_status: record.enrollment&.status || "missing",
        deduction_status: record.status,
        amount_cents: record.amount_cents,
        included:,
        issue: issue_for(record, included)
      )
    end

    def included?
      included
    end

    def self.issue_for(record, included)
      return "Ready for export" if included
      return "No deduction amount" if record.amount_cents.zero?
      return "Enrollment not accepted" unless record.enrollment&.status == "accepted"

      "Deduction status is #{record.status.humanize.downcase}"
    end

    private_class_method :issue_for
  end
end
