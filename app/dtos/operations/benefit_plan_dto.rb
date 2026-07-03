module Operations
  BenefitPlanDto = Data.define(
    :id,
    :name,
    :category,
    :carrier,
    :status,
    :monthly_premium_cents,
    :accepted_enrollment_count,
    :pending_enrollment_count
  ) do
    def self.from_record(record)
      enrollments = record.enrollments

      new(
        id: record.id,
        name: record.name,
        category: record.category,
        carrier: record.carrier,
        status: record.status,
        monthly_premium_cents: record.monthly_premium_cents,
        accepted_enrollment_count: enrollments.count { |enrollment| enrollment.status == "accepted" },
        pending_enrollment_count: enrollments.count { |enrollment| enrollment.status == "pending" }
      )
    end
  end
end
