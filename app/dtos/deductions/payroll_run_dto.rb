module Deductions
  PayrollRunDto = Data.define(:id, :period_start_on, :period_end_on, :pay_date, :status, :gross_pay_cents, :total_deductions_cents, :estimated_net_pay_cents) do
    def self.from_record(record)
      return unless record

      new(
        id: record.id,
        period_start_on: record.period_start_on,
        period_end_on: record.period_end_on,
        pay_date: record.pay_date,
        status: record.status,
        gross_pay_cents: record.gross_pay_cents,
        total_deductions_cents: record.total_deductions_cents,
        estimated_net_pay_cents: record.estimated_net_pay_cents
      )
    end

    def finalized?
      status == "finalized"
    end
  end
end
