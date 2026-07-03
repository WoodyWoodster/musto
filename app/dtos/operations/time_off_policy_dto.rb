module Operations
  TimeOffPolicyDto = Data.define(:id, :name, :status, :annual_hours, :carryover_hours) do
    def self.from_record(record)
      new(
        id: record.id,
        name: record.name,
        status: record.status,
        annual_hours: record.annual_hours,
        carryover_hours: record.carryover_hours
      )
    end
  end
end
