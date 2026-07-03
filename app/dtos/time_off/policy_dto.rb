module TimeOff
  PolicyDto = Data.define(
    :id,
    :name,
    :status,
    :accrual_method,
    :annual_hours,
    :carryover_hours,
    :paid,
    :request_count,
    :pending_hours,
    :approved_hours,
    :utilization_percent
  ) do
    def self.from_record(record)
      requests = record.time_off_requests.to_a
      allowance_hours = record.annual_hours + record.carryover_hours
      approved_hours = requests.select { |request| request.status == "approved" }.sum(&:hours)

      new(
        id: record.id,
        name: record.name,
        status: record.status,
        accrual_method: record.accrual_method,
        annual_hours: record.annual_hours,
        carryover_hours: record.carryover_hours,
        paid: record.paid?,
        request_count: requests.count,
        pending_hours: requests.select { |request| request.status == "requested" }.sum(&:hours),
        approved_hours:,
        utilization_percent: utilization_percent(allowance_hours, approved_hours)
      )
    end

    def paid_label
      paid ? "Paid" : "Unpaid"
    end

    def self.utilization_percent(allowance_hours, approved_hours)
      return 0 if allowance_hours.zero?

      ((approved_hours.to_f / allowance_hours.to_f) * 100).round
    end

    private_class_method :utilization_percent
  end
end
