module Employers
  EmployerSummaryDto = Data.define(
    :id,
    :name,
    :legal_name,
    :organization_name,
    :status,
    :employee_count,
    :benefit_plan_count,
    :enrollment_count,
    :accepted_enrollment_count,
    :payroll_run_count,
    :open_compliance_case_count
  ) do
    def self.from_record(record)
      new(
        id: record.id,
        name: record.name,
        legal_name: record.legal_name,
        organization_name: record.organization.name,
        status: record.status,
        employee_count: record.employees.size,
        benefit_plan_count: record.benefit_plans.size,
        enrollment_count: record.enrollments.size,
        accepted_enrollment_count: record.enrollments.count { |enrollment| enrollment.status == "accepted" },
        payroll_run_count: record.payroll_runs.size,
        open_compliance_case_count: record.compliance_cases.count { |item| item.status != "resolved" }
      )
    end
  end
end
