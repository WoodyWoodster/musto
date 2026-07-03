module OpenEnrollment
  PlanReadinessDto = Data.define(:id, :name, :category, :carrier, :status, :monthly_premium_cents, :accepted_count, :pending_count, :remote_pending_count) do
    def self.from_record(record)
      accepted = record.enrollments.count { |enrollment| enrollment.status == "accepted" }
      pending = record.enrollments.count { |enrollment| enrollment.status == "pending" }
      remote_pending = record.enrollments.count { |enrollment| enrollment.status == "accepted" && enrollment.vitable_id.blank? }

      new(
        id: record.id,
        name: record.name,
        category: record.category,
        carrier: record.carrier,
        status: record.status,
        monthly_premium_cents: record.monthly_premium_cents,
        accepted_count: accepted,
        pending_count: pending,
        remote_pending_count: remote_pending
      )
    end
  end
end
