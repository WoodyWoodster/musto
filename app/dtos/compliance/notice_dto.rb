module Compliance
  NoticeDto = Data.define(
    :id,
    :employee_id,
    :employee_name,
    :source,
    :notice_type,
    :title,
    :agency_name,
    :jurisdiction,
    :reference_number,
    :severity,
    :status,
    :received_on,
    :due_on,
    :amount_cents,
    :response_owner,
    :response_channel,
    :summary,
    :resolution_summary,
    :acknowledged_at,
    :responded_at,
    :resolved_at,
    :actionable,
    :resolved,
    :overdue,
    :due_soon
  ) do
    def self.from_record(notice)
      new(
        id: notice.id,
        employee_id: notice.employee_id,
        employee_name: notice.employee&.full_name,
        source: notice.source,
        notice_type: notice.notice_type,
        title: notice.title,
        agency_name: notice.agency_name,
        jurisdiction: notice.jurisdiction,
        reference_number: notice.reference_number,
        severity: notice.severity,
        status: notice.status,
        received_on: notice.received_on,
        due_on: notice.due_on,
        amount_cents: notice.amount_cents,
        response_owner: notice.response_owner,
        response_channel: notice.response_channel,
        summary: notice.summary,
        resolution_summary: notice.resolution_summary,
        acknowledged_at: notice.acknowledged_at,
        responded_at: notice.responded_at,
        resolved_at: notice.resolved_at,
        actionable: notice.open?,
        resolved: notice.resolved?,
        overdue: notice.overdue?,
        due_soon: notice.due_soon?
      )
    end
  end
end
