module Operations
  WorkforceEmployeeDto = Data.define(
    :id,
    :full_name,
    :title,
    :email,
    :department_name,
    :work_location_name,
    :compensation_cents,
    :pay_type,
    :benefits_status,
    :onboarding_status
  ) do
    def self.from_record(record)
      new(
        id: record.id,
        full_name: record.full_name,
        title: record.title,
        email: record.email,
        department_name: record.department&.name,
        work_location_name: record.work_location&.name,
        compensation_cents: record.compensation_cents,
        pay_type: record.pay_type,
        benefits_status: record.enrollments.any? { |enrollment| enrollment.status == "accepted" } ? "accepted" : "pending",
        onboarding_status: record.onboarding_status
      )
    end
  end
end
