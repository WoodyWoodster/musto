module Performance
  CalibrationHoldbackDto = Data.define(:review_id, :employee_name, :status, :reason) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys

      new(
        review_id: attributes.fetch("review_id", nil),
        employee_name: attributes.fetch("employee_name"),
        status: attributes.fetch("status"),
        reason: attributes.fetch("reason")
      )
    end
  end
end
