module OpenEnrollment
  BatchHoldbackDto = Data.define(:invitation_id, :employee_id, :employee_name, :reason, :status) do
    def self.from_hash(payload)
      new(
        invitation_id: payload.fetch("invitation_id"),
        employee_id: payload.fetch("employee_id"),
        employee_name: payload.fetch("employee_name"),
        reason: payload.fetch("reason"),
        status: payload.fetch("status")
      )
    end
  end
end
