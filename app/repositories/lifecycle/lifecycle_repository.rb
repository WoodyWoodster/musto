module Lifecycle
  class LifecycleRepository < ApplicationRepository
    def initialize(employer: nil)
      @employer = employer
    end

    def events
      return EmployeeLifecycleEvent.none unless @employer

      EmployeeLifecycleEvent
        .joins(:employee)
        .where(employees: { employer_id: @employer.id })
        .includes(employee: [ :department, :work_location ])
        .order(effective_on: :desc, created_at: :desc)
    end

    def batches
      payload = @employer&.settings.to_h.fetch("lifecycle_sync_batch", nil)
      payload.present? ? [ payload ] : []
    end

    def find_event(id)
      EmployeeLifecycleEvent.includes(employee: [ :department, :work_location ]).find(id)
    end

    def approve_event(event, reviewed_by:)
      event.approve!(reviewed_by:)
      event
    end

    def generate_sync_batch(requested_by:)
      approved_events = events.approved.to_a
      holdback_events = events.where(status: [ "draft", "blocked" ]).to_a
      lines = approved_events.map { |event| sync_line(event) }
      batch_id = "lifecycle_sync_#{@employer.id}_#{Time.current.to_i}"
      batch = {
        "batch_id" => batch_id,
        "generated_at" => Time.current.iso8601,
        "requested_by" => requested_by,
        "employer_id" => @employer.id,
        "status" => holdback_events.any? ? "needs_review" : "ready",
        "totals" => {
          "event_count" => lines.count,
          "employee_count" => approved_events.map(&:employee_id).uniq.count,
          "holdback_count" => holdback_events.count,
          "benefit_impact_count" => approved_events.count { |event| impact(event, "benefits_impact") != "none" },
          "payroll_impact_count" => approved_events.count { |event| impact(event, "payroll_impact") != "none" }
        },
        "events" => lines,
        "holdbacks" => holdback_events.map { |event| holdback_line(event) }
      }

      EmployeeLifecycleEvent.transaction do
        @employer.update!(settings: @employer.settings.to_h.merge("lifecycle_sync_batch" => batch))
        approved_events.each { |event| event.queue_for_sync!(batch_id:) }
      end

      batch
    end

    private

    def sync_line(event)
      {
        "event_id" => event.id,
        "employee_id" => event.employee_id,
        "employee_name" => event.employee.full_name,
        "remote_employee_id" => event.employee.vitable_id.presence || "pending_employee_#{event.employee_id}",
        "event_type" => event.event_type,
        "effective_on" => event.effective_on.iso8601,
        "summary" => event.summary,
        "source" => event.source,
        "payroll_impact" => impact(event, "payroll_impact"),
        "benefits_impact" => impact(event, "benefits_impact"),
        "compliance_impact" => impact(event, "compliance_impact"),
        "changes" => event.metadata.to_h.fetch("changes", {})
      }
    end

    def holdback_line(event)
      {
        "event_id" => event.id,
        "employee_id" => event.employee_id,
        "employee_name" => event.employee.full_name,
        "event_type" => event.event_type,
        "effective_on" => event.effective_on.iso8601,
        "status" => event.status,
        "reason" => event.status == "blocked" ? "Lifecycle event is blocked" : "Lifecycle event is not approved"
      }
    end

    def impact(event, key)
      event.metadata.to_h.stringify_keys.fetch(key, "none")
    end
  end
end
