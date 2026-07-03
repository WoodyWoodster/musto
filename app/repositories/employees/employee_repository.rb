module Employees
  class EmployeeRepository < ApplicationRepository
    def active_count
      Employee.active.count
    end

    def payroll_ready_count
      Employee.active.where.not(compensation_cents: 0).count
    end

    def find_profile(id)
      Employee
        .includes(
          :department,
          :work_location,
          :onboarding_tasks,
          :employee_documents,
          :compliance_cases,
          employer: [ :organization ],
          enrollments: [ :benefit_plan ],
          payroll_adjustments: [ :payroll_run ],
          payroll_deductions: [ :payroll_run, { enrollment: [ :benefit_plan ] } ],
          time_off_requests: [ :time_off_policy ]
        )
        .find(id)
    end

    def upsert(dto)
      Employee.find_or_initialize_by(employer_id: dto.employer_id, email: dto.email).tap do |employee|
        employee.assign_attributes(dto.to_attributes)
        employee.save
      end
    end
  end
end
