module Lifecycle
  EventDto = Data.define(
    :id,
    :employee_id,
    :employee_name,
    :employee_title,
    :department_name,
    :location_name,
    :event_type,
    :effective_on,
    :status,
    :summary,
    :source,
    :reviewed_at,
    :remote_employee_id,
    :payroll_impact,
    :benefits_impact,
    :compliance_impact,
    :changes
  ) do
    def self.from_record(record)
      employee = record.employee
      metadata = record.metadata.to_h.stringify_keys

      new(
        id: record.id,
        employee_id: record.employee_id,
        employee_name: employee.full_name,
        employee_title: employee.title,
        department_name: employee.department&.name || "Unassigned",
        location_name: employee.work_location&.name || "No location",
        event_type: record.event_type,
        effective_on: record.effective_on,
        status: record.status,
        summary: record.summary,
        source: record.source,
        reviewed_at: record.reviewed_at,
        remote_employee_id: employee.vitable_id,
        payroll_impact: metadata.fetch("payroll_impact", "none"),
        benefits_impact: metadata.fetch("benefits_impact", "none"),
        compliance_impact: metadata.fetch("compliance_impact", "none"),
        changes: metadata.fetch("changes", {})
      )
    end

    def draft?
      status == "draft"
    end

    def approved?
      status == "approved"
    end

    def sync_queued?
      status == "sync_queued"
    end

    def termination?
      event_type == "termination"
    end

    def remote_pending?
      remote_employee_id.blank?
    end
  end
end
