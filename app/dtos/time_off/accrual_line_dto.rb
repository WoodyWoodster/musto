module TimeOff
  AccrualLineDto = Data.define(:id, :employee_id, :employee_name, :policy_name, :accrual_type, :hours, :period_start_on, :period_end_on, :effective_on, :source, :status, :payroll_run_id, :approved_at) do
    def self.from_record(record)
      new(
        id: record.id,
        employee_id: record.employee_id,
        employee_name: record.employee.full_name,
        policy_name: record.time_off_policy.name,
        accrual_type: record.accrual_type,
        hours: record.hours,
        period_start_on: record.period_start_on,
        period_end_on: record.period_end_on,
        effective_on: record.effective_on,
        source: record.source,
        status: record.status,
        payroll_run_id: record.payroll_run_id,
        approved_at: record.approved_at
      )
    end

    def pending?
      status == "pending"
    end

    def period_label
      "#{period_start_on.strftime('%b %-d')} - #{period_end_on.strftime('%b %-d')}"
    end
  end
end
