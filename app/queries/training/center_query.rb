module Training
  class CenterQuery
    def initialize(employer_repository: Employers::EmployerRepository.new)
      @employer = employer_repository.first_for_operations
      @repository = TrainingRepository.new(employer: @employer)
    end

    def call
      programs = @repository.programs.to_a
      assignments = @repository.assignments.to_a
      batches = @repository.batches
      latest_batch = batches.first.to_h

      CenterDto.new(
        employer: Operations::EmployerContextDto.from_record(@employer),
        metrics: metrics(programs, assignments),
        programs: programs.map { |program| ProgramDto.from_record(program) },
        assignments: assignments.map { |assignment| AssignmentDto.from_record(assignment) },
        issues: issues(programs, assignments),
        audit_packets: batches.map { |payload| AuditPacketDto.from_hash(payload) },
        audit_lines: latest_batch.fetch("assignments", []).map { |payload| AuditLineDto.from_hash(payload) },
        audit_holdbacks: latest_batch.fetch("holdbacks", []).map { |payload| AuditHoldbackDto.from_hash(payload) },
        audit_payload: batches.first
      )
    end

    private

    def metrics(programs, assignments)
      active_programs = programs.count(&:active?)
      completed_assignments = assignments.count(&:complete?)
      completion_rate = assignments.empty? ? 0 : ((completed_assignments.to_f / assignments.count) * 100).round
      certificate_ready = assignments.count { |assignment| assignment.complete? && assignment.certificate_id.present? }
      overdue_assignments = assignments.count(&:overdue?)

      [
        MetricDto.new(label: "Active programs", value: active_programs, hint: "#{programs.count} total training programs", status: active_programs.positive? ? "active" : "needs_review", accent: "bg-emerald-500", format: "number"),
        MetricDto.new(label: "Completion rate", value: completion_rate, hint: "#{completed_assignments} of #{assignments.count} assignments complete", status: completion_rate >= 80 ? "ready" : "in_progress", accent: "bg-cyan-500", format: "percent"),
        MetricDto.new(label: "Certificates ready", value: certificate_ready, hint: "ready for compliance audit", status: certificate_ready.positive? ? "certificate_ready" : "pending", accent: "bg-indigo-500", format: "number"),
        MetricDto.new(label: "Overdue assignments", value: overdue_assignments, hint: "need employee follow-up", status: overdue_assignments.positive? ? "overdue" : "ready", accent: "bg-rose-500", format: "number")
      ]
    end

    def issues(programs, assignments)
      routes = Rails.application.routes.url_helpers
      items = []
      draft_programs = programs.select(&:draft?)
      certificate_ready = assignments.select { |assignment| assignment.complete? && assignment.certificate_id.present? }
      overdue_assignments = assignments.select(&:overdue?)
      missing_certificates = assignments.select { |assignment| assignment.complete? && assignment.certificate_id.blank? }
      open_assignments = assignments.select { |assignment| !assignment.complete? && !assignment.waived? && !assignment.overdue? }

      if draft_programs.any?
        items << IssueDto.new(key: "launch_training", title: "Launch required training", detail: "#{pluralized_count(draft_programs.count, "draft program")} #{be_verb(draft_programs.count)} ready to assign to active employees.", severity: "medium", status: "needs_review", owner: "People Ops", count: draft_programs.count, action_path: routes.training_path)
      end

      if certificate_ready.any?
        items << IssueDto.new(key: "audit_packet", title: "Generate audit packet", detail: "#{pluralized_count(certificate_ready.count, "certificate")} #{be_verb(certificate_ready.count)} ready for compliance evidence export.", severity: "medium", status: "certificate_ready", owner: "People Ops", count: certificate_ready.count, action_path: routes.training_path)
      end

      if overdue_assignments.any?
        items << IssueDto.new(key: "overdue_training", title: "Overdue training follow-up", detail: "#{pluralized_count(overdue_assignments.count, "assignment")} #{be_verb(overdue_assignments.count)} past due and should be escalated before payroll close.", severity: "high", status: "overdue", owner: "Managers", count: overdue_assignments.count, action_path: routes.training_path)
      end

      if missing_certificates.any?
        items << IssueDto.new(key: "missing_certificates", title: "Attach missing certificates", detail: "#{pluralized_count(missing_certificates.count, "completed assignment")} #{need_verb(missing_certificates.count)} certificate references before audit export.", severity: "medium", status: "needs_review", owner: "People Ops", count: missing_certificates.count, action_path: routes.training_path)
      end

      if open_assignments.any?
        items << IssueDto.new(key: "open_training", title: "Training completion still in progress", detail: "#{pluralized_count(open_assignments.count, "assignment")} remain open across active programs.", severity: "low", status: "in_progress", owner: "Employees", count: open_assignments.count, action_path: routes.training_path)
      end

      return items if items.any?

      [
        IssueDto.new(key: "training_ready", title: "Training program is audit-ready", detail: "Assignments, certificates, and evidence packets are current.", severity: "low", status: "ready", owner: "People Ops", count: assignments.count, action_path: routes.training_path)
      ]
    end

    def pluralized_count(count, noun)
      "#{count} #{noun.pluralize(count)}"
    end

    def be_verb(count)
      count == 1 ? "is" : "are"
    end

    def need_verb(count)
      count == 1 ? "needs" : "need"
    end
  end
end
