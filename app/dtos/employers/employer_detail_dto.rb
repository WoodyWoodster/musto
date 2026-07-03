module Employers
  EmployerDetailDto = Data.define(
    :id,
    :name,
    :legal_name,
    :ein,
    :vitable_id,
    :organization_name,
    :status,
    :employee_count,
    :department_count,
    :benefit_plan_count,
    :open_compliance_case_count,
    :employees,
    :benefit_plans
  ) do
    def self.from_record(record)
      new(
        id: record.id,
        name: record.name,
        legal_name: record.legal_name,
        ein: record.ein,
        vitable_id: record.vitable_id,
        organization_name: record.organization.name,
        status: record.status,
        employee_count: record.employees.size,
        department_count: record.departments.size,
        benefit_plan_count: record.benefit_plans.size,
        open_compliance_case_count: record.compliance_cases.count { |item| item.status != "resolved" },
        employees: record.employees.map { |employee| RosterEmployeeDto.from_record(employee) },
        benefit_plans: record.benefit_plans.map { |plan| BenefitPlanSummaryDto.from_record(plan) }
      )
    end
  end
end
