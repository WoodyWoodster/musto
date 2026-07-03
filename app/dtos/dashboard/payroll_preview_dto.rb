module Dashboard
  PayrollPreviewDto = Data.define(:id, :pay_date, :gross_pay_cents, :status) do
    def self.from_record(record)
      return unless record

      new(
        id: record.id,
        pay_date: record.pay_date,
        gross_pay_cents: record.gross_pay_cents,
        status: record.status
      )
    end
  end
end
