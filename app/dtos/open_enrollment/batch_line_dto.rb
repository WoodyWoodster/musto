module OpenEnrollment
  BatchLineDto = Data.define(:invitation_id, :employee_id, :employee_name, :status, :due_on, :sent_at, :last_reminded_at) do
    def self.from_hash(payload)
      new(
        invitation_id: payload.fetch("invitation_id"),
        employee_id: payload.fetch("employee_id"),
        employee_name: payload.fetch("employee_name"),
        status: payload.fetch("status"),
        due_on: Date.iso8601(payload.fetch("due_on")),
        sent_at: parse_time(payload["sent_at"]),
        last_reminded_at: parse_time(payload["last_reminded_at"])
      )
    end

    def self.parse_time(value)
      Time.zone.parse(value) if value.present?
    end

    private_class_method :parse_time
  end
end
