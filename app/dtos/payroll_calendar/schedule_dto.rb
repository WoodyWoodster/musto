module PayrollCalendar
  ScheduleDto = Data.define(:id, :name, :cadence, :status, :period_anchor_on, :next_period_start_on, :next_period_end_on, :next_pay_date, :approval_deadline_at, :funding_deadline_at, :timezone) do
    def self.from_record(record)
      return unless record

      new(
        id: record.id,
        name: record.name,
        cadence: record.cadence,
        status: record.status,
        period_anchor_on: record.period_anchor_on,
        next_period_start_on: record.next_period_start_on,
        next_period_end_on: record.next_period_end_on,
        next_pay_date: record.next_pay_date,
        approval_deadline_at: record.approval_deadline_at,
        funding_deadline_at: record.funding_deadline_at,
        timezone: record.timezone
      )
    end

    def active?
      status == "active"
    end

    def days_until_payday
      (next_pay_date - Date.current).to_i
    end
  end
end
