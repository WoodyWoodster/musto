module Operations
  WorkLocationDto = Data.define(:id, :name, :status, :city, :country, :employee_count) do
    def self.from_record(record)
      new(
        id: record.id,
        name: record.name,
        status: record.remote? ? "remote" : record.state.presence || "active",
        city: record.city,
        country: record.country,
        employee_count: record.employees.size
      )
    end
  end
end
