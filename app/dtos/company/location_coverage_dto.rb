module Company
  LocationCoverageDto = Data.define(:id, :name, :city, :state, :country, :remote, :employee_count, :status) do
    def self.from_record(record)
      new(
        id: record.id,
        name: record.name,
        city: record.city,
        state: record.state,
        country: record.country,
        remote: record.remote?,
        employee_count: record.employees.size,
        status: record.remote? ? "remote" : "active"
      )
    end

    def remote_label
      remote ? "Remote" : [ city, state ].compact_blank.join(", ")
    end
  end
end
