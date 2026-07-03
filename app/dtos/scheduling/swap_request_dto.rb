module Scheduling
  SwapRequestDto = Data.define(:id, :shift_id, :requester_id, :requester_name, :target_employee_id, :target_employee_name, :role, :status, :reason, :starts_at, :ends_at, :submitted_at, :reviewed_at, :reviewed_by) do
    def self.from_record(record)
      new(
        id: record.id,
        shift_id: record.work_shift_id,
        requester_id: record.requester_id,
        requester_name: record.requester.full_name,
        target_employee_id: record.target_employee_id,
        target_employee_name: record.target_employee&.full_name || "Open coverage",
        role: record.work_shift.role,
        status: record.status,
        reason: record.reason,
        starts_at: record.work_shift.starts_at,
        ends_at: record.work_shift.ends_at,
        submitted_at: record.submitted_at,
        reviewed_at: record.reviewed_at,
        reviewed_by: record.reviewed_by
      )
    end

    def reviewable?
      status == "submitted"
    end
  end
end
