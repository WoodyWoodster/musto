module Lifecycle
  class CommandCenterQuery
    def initialize(employer_repository: Employers::EmployerRepository.new)
      @employer = employer_repository.first_for_operations
      @repository = LifecycleRepository.new(employer: @employer)
    end

    def call
      events = @repository.events.to_a
      batches = @repository.batches
      latest_batch = batches.first.to_h

      CenterDto.new(
        employer: Operations::EmployerContextDto.from_record(@employer),
        metrics: metrics(events),
        events: events.map { |event| EventDto.from_record(event) },
        impact_items: impact_items(events),
        batches: batches.map { |payload| SyncBatchDto.from_hash(payload) },
        batch_lines: latest_batch.fetch("events", []).map { |payload| SyncLineDto.from_hash(payload) },
        batch_holdbacks: latest_batch.fetch("holdbacks", []).map { |payload| SyncHoldbackDto.from_hash(payload) },
        batch_payload: batches.first
      )
    end

    private

    def metrics(events)
      pending_count = events.count(&:draft?)
      approved_count = events.count(&:approved?)
      queued_count = events.count(&:sync_queued?)
      termination_count = events.count(&:termination?)

      [
        MetricDto.new(label: "Pending review", value: pending_count, hint: "draft employee changes", status: pending_count.positive? ? "needs_review" : "ready", accent: "bg-amber-500", format: "number"),
        MetricDto.new(label: "Approved changes", value: approved_count, hint: "ready for HRIS sync", status: approved_count.positive? ? "ready" : "needs_review", accent: "bg-emerald-500", format: "number"),
        MetricDto.new(label: "Sync queued", value: queued_count, hint: "local Vitable payloads", status: queued_count.positive? ? "sync_queued" : "pending", accent: "bg-indigo-500", format: "number"),
        MetricDto.new(label: "Terminations", value: termination_count, hint: "final pay and benefits impact", status: termination_count.positive? ? "needs_review" : "ready", accent: "bg-rose-500", format: "number")
      ]
    end

    def impact_items(events)
      routes = Rails.application.routes.url_helpers
      items = []
      pending_count = events.count(&:draft?)
      remote_pending = events.count { |event| event.employee.vitable_id.blank? }
      final_pay_count = events.count { |event| event.termination? && event.status != "sync_queued" }
      benefits_impact_count = events.count { |event| event.metadata.to_h.stringify_keys.fetch("benefits_impact", "none") != "none" && event.status != "sync_queued" }

      if pending_count.positive?
        items << ImpactItemDto.new(key: "pending_review", title: "Approve employee changes", detail: "#{pending_count} lifecycle events need approval before payroll, benefits, and Vitable sync.", severity: "medium", status: "needs_review", owner: "People Ops", action_path: routes.lifecycle_path)
      end

      if final_pay_count.positive?
        items << ImpactItemDto.new(key: "final_pay", title: "Review final pay timing", detail: "#{final_pay_count} termination events need final pay and offboarding review.", severity: "high", status: "needs_review", owner: "Payroll", action_path: routes.payroll_path)
      end

      if benefits_impact_count.positive?
        items << ImpactItemDto.new(key: "benefits_impact", title: "Confirm benefits eligibility impact", detail: "#{benefits_impact_count} approved or pending changes affect benefit eligibility or coverage.", severity: "medium", status: "needs_review", owner: "Benefits", action_path: routes.benefits_eligibility_path)
      end

      if remote_pending.positive?
        items << ImpactItemDto.new(key: "remote_ids", title: "Prepare remote employee mappings", detail: "#{remote_pending} events involve employees without Vitable IDs and will create or match records at sync time.", severity: "low", status: "remote_pending", owner: "Integrations", action_path: routes.integrations_path)
      end

      return items if items.any?

      [
        ImpactItemDto.new(key: "lifecycle_ready", title: "Lifecycle queue is clean", detail: "Employee changes are approved, queued, or ready for the next HRIS sync batch.", severity: "low", status: "ready", owner: "People Ops", action_path: routes.generate_lifecycle_sync_batch_path)
      ]
    end
  end
end
