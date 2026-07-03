module WorkersComp
  ClaimDto = Data.define(:id, :employee_id, :employee_name, :employee_title, :policy_id, :claim_number, :incident_on, :reported_on, :status, :severity, :injury_type, :body_part, :description, :lost_time_days, :reserve_cents, :paid_cents, :return_to_work_on, :closed_at, :closable) do
    def self.from_record(record)
      new(
        id: record.id,
        employee_id: record.employee_id,
        employee_name: record.employee.full_name,
        employee_title: record.employee.title,
        policy_id: record.workers_comp_policy_id,
        claim_number: record.claim_number,
        incident_on: record.incident_on,
        reported_on: record.reported_on,
        status: record.status,
        severity: record.severity,
        injury_type: record.injury_type,
        body_part: record.body_part,
        description: record.description,
        lost_time_days: record.lost_time_days,
        reserve_cents: record.reserve_cents,
        paid_cents: record.paid_cents,
        return_to_work_on: record.return_to_work_on,
        closed_at: record.closed_at,
        closable: record.closable?
      )
    end

    def open?
      status.in?(%w[reported investigating accepted])
    end

    def closable?
      closable
    end
  end
end
