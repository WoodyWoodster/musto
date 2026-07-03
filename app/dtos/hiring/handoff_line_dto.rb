module Hiring
  HandoffLineDto = Data.define(:candidate_id, :employee_id, :candidate_name, :job_title, :department_name, :start_on, :task_count, :status) do
    def self.from_hash(payload)
      attributes = payload.to_h.stringify_keys

      new(
        candidate_id: attributes.fetch("candidate_id"),
        employee_id: attributes.fetch("employee_id"),
        candidate_name: attributes.fetch("candidate_name"),
        job_title: attributes.fetch("job_title"),
        department_name: attributes.fetch("department_name", nil),
        start_on: Date.iso8601(attributes.fetch("start_on")),
        task_count: attributes.fetch("task_count", 0),
        status: attributes.fetch("status")
      )
    end
  end
end
