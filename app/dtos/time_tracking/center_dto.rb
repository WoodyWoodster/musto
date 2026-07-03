module TimeTracking
  CenterDto = Data.define(
    :employer,
    :metrics,
    :entries,
    :employees,
    :departments,
    :exceptions,
    :exports,
    :export_payload
  ) do
    def generated?
      export_payload.present?
    end

    def latest_export
      exports.first
    end

    def pending_entries
      entries.select(&:submitted?)
    end
  end
end
