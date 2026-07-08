module Benefits
  class OffboardingRepository < ApplicationRepository
    PACKET_KEY = "benefits_offboarding_packet"

    def initialize(employer: nil)
      @employer = employer
    end

    def events
      return EmployeeLifecycleEvent.none unless @employer

      EmployeeLifecycleEvent
        .joins(:employee)
        .where(event_type: "termination", employees: { employer_id: @employer.id })
        .includes(employee: [ :department, :work_location, :dependents, enrollments: [ :benefit_plan ] ])
        .order(effective_on: :asc, created_at: :desc)
    end

    def coverage_events
      events.select { |event| benefit_impact(event) == "end_coverage" }
    end

    def coverage_lines
      coverage_events.flat_map { |event| coverage_lines_for(event) }
    end

    def issues
      coverage_events.flat_map { |event| holdbacks_for(event) }
    end

    def latest_packet
      @employer&.settings.to_h.fetch(PACKET_KEY, nil)
    end

    def generate_packet(requested_by:)
      selected_events = coverage_events
      lines = selected_events.flat_map { |event| coverage_lines_for(event) }
      ready_lines = lines.select { |line| line.fetch("status") == "ready" }
      holdbacks = selected_events.flat_map { |event| holdbacks_for(event) } + lines.reject { |line| line.fetch("status") == "ready" }.map { |line| line_holdback(line) }
      packet = {
        "packet_id" => "benefits_offboarding_#{@employer.id}_#{Time.current.to_i}",
        "generated_at" => Time.current.iso8601,
        "requested_by" => requested_by,
        "employer_id" => @employer.id,
        "status" => holdbacks.any? ? "needs_review" : "ready",
        "endpoint" => Vitable::EndpointCatalog::EMPLOYER_CENSUS_SYNC_BY_EMPLOYER,
        "deactivation_strategy" => "omit_employee_from_next_census_sync",
        "totals" => {
          "event_count" => selected_events.count,
          "member_count" => ready_lines.count,
          "employee_count" => ready_lines.map { |line| line.fetch("employee_id") }.uniq.count,
          "holdback_count" => holdbacks.count
        },
        "terminations" => ready_lines,
        "holdbacks" => holdbacks
      }

      @employer.update!(settings: @employer.settings.to_h.merge(PACKET_KEY => packet))
      packet
    end

    private

    def coverage_lines_for(event)
      event.employee.enrollments.select { |enrollment| enrollment.status == "accepted" }.flat_map do |enrollment|
        [ employee_line(event, enrollment) ] + event.employee.dependents.select(&:eligible?).map { |dependent| dependent_line(event, enrollment, dependent) }
      end
    end

    def employee_line(event, enrollment)
      line_for(
        event:,
        enrollment:,
        member_type: "employee",
        member_id: event.employee_id,
        member_name: event.employee.full_name,
        relationship: "employee",
        remote_member_id: event.employee.vitable_id
      )
    end

    def dependent_line(event, enrollment, dependent)
      line_for(
        event:,
        enrollment:,
        member_type: "dependent",
        member_id: dependent.id,
        member_name: dependent.full_name,
        relationship: dependent.relationship,
        remote_member_id: dependent.vitable_id
      )
    end

    def line_for(event:, enrollment:, member_type:, member_id:, member_name:, relationship:, remote_member_id:)
      status, reason = line_status(event, enrollment, remote_member_id)
      {
        "event_id" => event.id,
        "employee_id" => event.employee_id,
        "employee_name" => event.employee.full_name,
        "member_type" => member_type,
        "member_id" => member_id,
        "member_name" => member_name,
        "relationship" => relationship,
        "plan_name" => enrollment.benefit_plan.name,
        "plan_category" => enrollment.benefit_plan.category,
        "remote_member_id" => remote_member_id,
        "remote_enrollment_id" => enrollment.vitable_id,
        "coverage_end_on" => event.effective_on.iso8601,
        "status" => status,
        "reason" => reason
      }
    end

    def line_status(event, enrollment, remote_member_id)
      return [ "needs_review", "Lifecycle event is not approved for offboarding." ] unless event.approved? || event.sync_queued?
      return [ "remote_pending", "Remote member ID is missing." ] if remote_member_id.blank?
      return [ "remote_pending", "Remote enrollment ID is missing." ] if enrollment.vitable_id.blank?

      [ "ready", "Coverage termination is ready for Vitable sync." ]
    end

    def holdbacks_for(event)
      holdbacks = []
      holdbacks << issue(event, "event_not_approved", "high", event.status, "Lifecycle event must be approved before coverage termination.") unless event.approved? || event.sync_queued?
      holdbacks << issue(event, "missing_coverage", "medium", "needs_review", "No accepted benefit coverage found for this employee.") if event.employee.enrollments.none? { |enrollment| enrollment.status == "accepted" }
      holdbacks << issue(event, "missing_remote_employee", "medium", "remote_pending", "Remote employee ID is required before sending termination.") if event.employee.vitable_id.blank?
      holdbacks
    end

    def line_holdback(line)
      {
        "event_id" => line.fetch("event_id"),
        "employee_id" => line.fetch("employee_id"),
        "employee_name" => line.fetch("employee_name"),
        "severity" => "medium",
        "status" => line.fetch("status"),
        "reason_code" => "#{line.fetch("member_type")}_#{line.fetch("status")}",
        "reason" => "#{line.fetch("member_name")}: #{line.fetch("reason")}"
      }
    end

    def issue(event, reason_code, severity, status, reason)
      {
        "event_id" => event.id,
        "employee_id" => event.employee_id,
        "employee_name" => event.employee.full_name,
        "severity" => severity,
        "status" => status,
        "reason_code" => reason_code,
        "reason" => reason
      }
    end

    def benefit_impact(event)
      event.metadata.to_h.stringify_keys.fetch("benefits_impact", "none")
    end
  end
end
