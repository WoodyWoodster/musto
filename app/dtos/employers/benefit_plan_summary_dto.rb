module Employers
  BenefitPlanSummaryDto = Data.define(:id, :name, :category, :carrier, :status, :monthly_premium_cents) do
    def self.from_record(record)
      new(
        id: record.id,
        name: record.name,
        category: record.category,
        carrier: record.carrier,
        status: record.status,
        monthly_premium_cents: record.monthly_premium_cents
      )
    end
  end
end
