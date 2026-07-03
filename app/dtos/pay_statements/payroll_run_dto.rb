module PayStatements
  PayrollRunDto = Data.define(:id, :period_start_on, :period_end_on, :pay_date, :status, :employee_count, :net_pay_cents) do
    def self.from_payroll_detail(detail)
      return unless detail

      new(
        id: detail.id,
        period_start_on: detail.period_start_on,
        period_end_on: detail.period_end_on,
        pay_date: detail.pay_date,
        status: detail.status,
        employee_count: detail.employee_count,
        net_pay_cents: detail.estimated_net_pay_cents
      )
    end
  end
end
