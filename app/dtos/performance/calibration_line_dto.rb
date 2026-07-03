module Performance
  CalibrationLineDto = Data.define(:review_id, :employee_id, :employee_name, :department_name, :reviewer_name, :rating, :status, :due_on) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys

      new(
        review_id: attributes.fetch("review_id"),
        employee_id: attributes.fetch("employee_id"),
        employee_name: attributes.fetch("employee_name"),
        department_name: attributes.fetch("department_name", nil),
        reviewer_name: attributes.fetch("reviewer_name"),
        rating: attributes.fetch("rating", nil),
        status: attributes.fetch("status"),
        due_on: Date.iso8601(attributes.fetch("due_on"))
      )
    end
  end
end
