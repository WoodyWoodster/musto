module Employees
  class EmployeeRepository < ApplicationRepository
    def active_count
      Employee.active.count
    end

    def payroll_ready_count
      Employee.active.where.not(compensation_cents: 0).count
    end

    def upsert(dto)
      Employee.find_or_initialize_by(employer_id: dto.employer_id, email: dto.email).tap do |employee|
        employee.assign_attributes(dto.to_attributes)
        employee.save
      end
    end
  end
end
