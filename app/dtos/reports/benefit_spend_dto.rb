module Reports
  BenefitSpendDto = Data.define(
    :plan_id,
    :plan_name,
    :category,
    :carrier,
    :status,
    :accepted_count,
    :pending_count,
    :monthly_premium_cents,
    :monthly_cost_cents
  ) do
    def self.from_record(record)
      accepted_count = record.enrollments.count { |enrollment| enrollment.status == "accepted" }

      new(
        plan_id: record.id,
        plan_name: record.name,
        category: record.category,
        carrier: record.carrier,
        status: record.status,
        accepted_count:,
        pending_count: record.enrollments.count { |enrollment| enrollment.status == "pending" },
        monthly_premium_cents: record.monthly_premium_cents,
        monthly_cost_cents: accepted_count * record.monthly_premium_cents
      )
    end
  end
end
