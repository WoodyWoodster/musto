module Vitable
  EmployeeLifecycleReconciliationDto = Data.define(:enrollment_ids, :deduction_ids) do
    def self.empty
      new(enrollment_ids: [], deduction_ids: [])
    end

    def changed?
      enrollment_ids.any? || deduction_ids.any?
    end

    def merge(other)
      self.class.new(
        enrollment_ids: enrollment_ids + other.enrollment_ids,
        deduction_ids: deduction_ids + other.deduction_ids
      )
    end

    def applied_changes
      enrollment_ids.map { |id| "enrollments.#{id}" } +
        deduction_ids.map { |id| "payroll_deductions.#{id}" }
    end

    def to_metadata
      {
        "inactive_enrollment_count" => enrollment_ids.count,
        "inactive_payroll_deduction_count" => deduction_ids.count,
        "inactive_enrollment_ids" => enrollment_ids,
        "inactive_payroll_deduction_ids" => deduction_ids
      }
    end
  end
end
