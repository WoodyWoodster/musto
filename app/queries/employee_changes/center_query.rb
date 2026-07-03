module EmployeeChanges
  class CenterQuery
    REQUEST_TYPES = %w[profile_update direct_deposit tax_withholding emergency_contact work_location].freeze

    def initialize(employer_repository: Employers::EmployerRepository.new)
      @employer = employer_repository.first_for_operations
      @repository = ChangeRequestRepository.new(employer: @employer)
    end

    def call
      requests = @repository.requests.to_a
      batches = @repository.batches
      latest_batch = batches.first.to_h

      CenterDto.new(
        employer: Operations::EmployerContextDto.from_record(@employer),
        metrics: metrics(requests),
        requests: requests.map { |request| RequestDto.from_record(request) },
        type_summaries: type_summaries(requests),
        impact_items: impact_items(requests),
        sync_batches: batches.map { |payload| SyncBatchDto.from_hash(payload) },
        sync_lines: latest_batch.fetch("requests", []).map { |payload| SyncLineDto.from_hash(payload) },
        sync_holdbacks: latest_batch.fetch("holdbacks", []).map { |payload| SyncHoldbackDto.from_hash(payload) },
        sync_payload: batches.first
      )
    end

    private

    def metrics(requests)
      submitted = requests.count(&:submitted?)
      applied = requests.count(&:applied?)
      queued = requests.count(&:sync_queued?)
      payroll_impact = requests.count { |request| request.payroll_impact != "none" && !request.sync_queued? }

      [
        MetricDto.new(label: "Pending review", value: submitted, hint: "employee-submitted requests", status: submitted.positive? ? "needs_review" : "ready", accent: "bg-amber-500", format: "number"),
        MetricDto.new(label: "Applied locally", value: applied, hint: "ready for Vitable sync", status: applied.positive? ? "ready" : "pending", accent: "bg-emerald-500", format: "number"),
        MetricDto.new(label: "Sync queued", value: queued, hint: "profile change payloads", status: queued.positive? ? "sync_queued" : "pending", accent: "bg-indigo-500", format: "number"),
        MetricDto.new(label: "Payroll impact", value: payroll_impact, hint: "tax or bank updates", status: payroll_impact.positive? ? "needs_review" : "ready", accent: "bg-cyan-500", format: "number")
      ]
    end

    def type_summaries(requests)
      grouped = requests.group_by(&:request_type)

      REQUEST_TYPES.map do |request_type|
        type_requests = grouped.fetch(request_type, [])
        submitted_count = type_requests.count(&:submitted?)
        applied_count = type_requests.count(&:applied?)

        TypeSummaryDto.new(
          request_type:,
          label: request_type.humanize,
          request_count: type_requests.count,
          submitted_count:,
          applied_count:,
          status: submitted_count.positive? ? "needs_review" : "ready",
          accent: type_accent(request_type)
        )
      end
    end

    def impact_items(requests)
      routes = Rails.application.routes.url_helpers
      items = []
      submitted = requests.select(&:submitted?)
      applied = requests.select(&:applied?)
      payroll = requests.select { |request| request.payroll_impact != "none" && !request.sync_queued? }
      benefits = requests.select { |request| request.benefits_impact != "none" && !request.sync_queued? }
      remote_pending = requests.select { |request| request.employee.vitable_id.blank? }

      if submitted.any?
        items << ImpactItemDto.new(key: "pending_review", title: "Review employee changes", detail: "#{pluralized_count(submitted.count, "request")} #{be_verb(submitted.count)} waiting for People Ops approval.", severity: "medium", status: "needs_review", owner: "People Ops", action_path: routes.employee_changes_path)
      end

      if applied.any?
        items << ImpactItemDto.new(key: "sync_ready", title: "Generate profile sync", detail: "#{pluralized_count(applied.count, "applied request")} #{be_verb(applied.count)} ready to package for Vitable and audit systems.", severity: "medium", status: "ready", owner: "Integrations", action_path: routes.employee_changes_path)
      end

      if payroll.any?
        items << ImpactItemDto.new(key: "payroll_impact", title: "Review payroll impact", detail: "#{pluralized_count(payroll.count, "request")} change tax withholding or direct deposit setup.", severity: "high", status: "needs_review", owner: "Payroll", action_path: routes.payroll_funding_path)
      end

      if benefits.any?
        items << ImpactItemDto.new(key: "benefits_impact", title: "Confirm eligibility impact", detail: "#{pluralized_count(benefits.count, "request")} may affect work-state eligibility or benefit records.", severity: "medium", status: "needs_review", owner: "Benefits", action_path: routes.benefits_eligibility_path)
      end

      if remote_pending.any?
        items << ImpactItemDto.new(key: "remote_ids", title: "Prepare remote employee IDs", detail: "#{pluralized_count(remote_pending.count, "request")} involve employees without Vitable IDs.", severity: "low", status: "remote_pending", owner: "Integrations", action_path: routes.integrations_path)
      end

      return items if items.any?

      [
        ImpactItemDto.new(key: "employee_changes_ready", title: "Self-service inbox is clear", detail: "Employee changes are reviewed, synced, or ready for the next intake.", severity: "low", status: "ready", owner: "People Ops", action_path: routes.employee_changes_path)
      ]
    end

    def type_accent(request_type)
      {
        "profile_update" => "bg-sky-500",
        "direct_deposit" => "bg-emerald-500",
        "tax_withholding" => "bg-violet-500",
        "emergency_contact" => "bg-rose-500",
        "work_location" => "bg-indigo-500"
      }.fetch(request_type, "bg-slate-500")
    end

    def pluralized_count(count, noun)
      "#{count} #{noun.pluralize(count)}"
    end

    def be_verb(count)
      count == 1 ? "is" : "are"
    end
  end
end
