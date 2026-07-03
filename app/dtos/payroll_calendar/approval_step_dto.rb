module PayrollCalendar
  ApprovalStepDto = Data.define(:id, :key, :title, :owner, :status, :severity, :position, :due_at, :completed_at, :completed_by, :detail, :count, :amount_cents) do
    def self.from_record(record)
      metadata = record.metadata.to_h

      new(
        id: record.id,
        key: record.key,
        title: record.title,
        owner: record.owner,
        status: record.status,
        severity: record.severity,
        position: record.position,
        due_at: record.due_at,
        completed_at: record.completed_at,
        completed_by: record.completed_by,
        detail: metadata.fetch("detail", "Review and certify this payroll control."),
        count: metadata.fetch("count", 0),
        amount_cents: metadata.fetch("amount_cents", 0)
      )
    end

    def completed?
      status == "completed"
    end

    def blocked?
      status == "blocked"
    end

    def completable?
      !completed? && !blocked?
    end

    def overdue?
      !completed? && due_at < Time.current
    end
  end
end
