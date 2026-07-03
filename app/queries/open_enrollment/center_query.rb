module OpenEnrollment
  class CenterQuery
    def initialize(employer_repository: Employers::EmployerRepository.new)
      @employer = employer_repository.first_for_operations
      @repository = CampaignRepository.new(employer: @employer)
    end

    def call
      campaign = @repository.current_campaign
      invitations = @repository.invitations.to_a
      enrollments = @repository.enrollments.to_a
      dependents = @repository.dependents.to_a
      plans = @repository.plans.to_a
      batches = @repository.batches
      latest_batch = batches.first.to_h
      enrollments_by_employee = enrollments.group_by(&:employee_id)
      dependents_by_employee = dependents.group_by(&:employee_id)

      CenterDto.new(
        employer: Operations::EmployerContextDto.from_record(@employer),
        campaign: CampaignDto.from_record(campaign),
        metrics: metrics(campaign, invitations, enrollments, dependents, plans),
        plans: plans.map { |plan| PlanReadinessDto.from_record(plan) },
        invitations: invitations.map { |invitation| InvitationDto.from_record(invitation, enrollments: enrollments_by_employee.fetch(invitation.employee_id, []), dependents: dependents_by_employee.fetch(invitation.employee_id, [])) },
        issues: issues(campaign, invitations, enrollments, dependents, plans),
        batches: batches.map { |payload| BatchDto.from_hash(payload) },
        batch_lines: latest_batch.fetch("lines", []).map { |payload| BatchLineDto.from_hash(payload) },
        batch_holdbacks: latest_batch.fetch("holdbacks", []).map { |payload| BatchHoldbackDto.from_hash(payload) },
        batch_payload: batches.first
      )
    end

    private

    def metrics(campaign, invitations, enrollments, dependents, plans)
      invited_count = invitations.count(&:sent?)
      completed_count = invitations.count(&:completed?)
      pending_elections = enrollments.count { |enrollment| enrollment.status == "pending" }
      dependent_blockers = dependents.count { |dependent| !dependent.eligible? }
      remote_pending = enrollments.count { |enrollment| enrollment.status == "accepted" && enrollment.vitable_id.blank? }

      [
        MetricDto.new(label: "Campaign status", value: campaign&.active? ? 1 : 0, hint: campaign ? "#{campaign.name} for #{campaign.plan_year}" : "No open enrollment campaign", status: campaign&.active? ? "active" : "draft", accent: "bg-cyan-500", format: "number"),
        MetricDto.new(label: "Invited employees", value: invited_count, hint: "#{invitations.count} campaign invitations", status: invited_count.positive? ? "in_progress" : "needs_review", accent: "bg-indigo-500", format: "number"),
        MetricDto.new(label: "Completed elections", value: completed_count, hint: "#{pending_elections} pending enrollment decisions", status: pending_elections.zero? && completed_count.positive? ? "ready" : "needs_review", accent: "bg-emerald-500", format: "number"),
        MetricDto.new(label: "Vitable blockers", value: dependent_blockers + remote_pending + (plans.empty? ? 1 : 0), hint: "#{dependent_blockers} dependent reviews · #{remote_pending} remote IDs pending", status: dependent_blockers.positive? || remote_pending.positive? || plans.empty? ? "needs_review" : "ready", accent: "bg-amber-500", format: "number")
      ]
    end

    def issues(campaign, invitations, enrollments, dependents, plans)
      routes = Rails.application.routes.url_helpers
      items = []
      pending_invitations = invitations.reject { |invitation| invitation.completed? || invitation.waived? }
      pending_enrollments = enrollments.select { |enrollment| enrollment.status == "pending" }
      dependent_reviews = dependents.reject(&:eligible?)
      remote_pending = enrollments.select { |enrollment| enrollment.status == "accepted" && enrollment.vitable_id.blank? }

      if campaign.blank?
        items << IssueDto.new(key: "missing_campaign", title: "Launch open enrollment", detail: "Create the next plan-year campaign and send employee invitations before eligibility handoff.", severity: "high", status: "blocked", owner: "Benefits", count: 1, action_path: routes.benefits_open_enrollment_path)
      end

      if plans.empty?
        items << IssueDto.new(key: "missing_plans", title: "Publish benefit plans", detail: "Open enrollment needs at least one available benefit plan before employees can elect coverage.", severity: "critical", status: "blocked", owner: "Benefits", count: 1, action_path: routes.benefits_path)
      end

      if pending_invitations.any?
        items << IssueDto.new(key: "employee_followup", title: "Follow up with employees", detail: "#{pending_invitations.count} employees have not completed or waived open enrollment.", severity: "medium", status: "needs_review", owner: "People Ops", count: pending_invitations.count, action_path: routes.benefits_open_enrollment_path)
      end

      if pending_enrollments.any?
        items << IssueDto.new(key: "pending_elections", title: "Resolve pending elections", detail: "#{pending_enrollments.count} benefit elections still need accept or waive decisions.", severity: "medium", status: "needs_review", owner: "Benefits", count: pending_enrollments.count, action_path: routes.benefits_path)
      end

      if dependent_reviews.any?
        items << IssueDto.new(key: "dependent_review", title: "Review dependent eligibility", detail: "#{dependent_reviews.count} dependents can block eligibility export until reviewed.", severity: "high", status: "blocked", owner: "Benefits", count: dependent_reviews.count, action_path: routes.benefits_eligibility_path)
      end

      if remote_pending.any?
        items << IssueDto.new(key: "remote_id_backfill", title: "Backfill Vitable enrollment IDs", detail: "#{remote_pending.count} accepted elections need remote IDs after the Vitable sync.", severity: "low", status: "remote_pending", owner: "Integrations", count: remote_pending.count, action_path: routes.benefits_eligibility_path)
      end

      return items if items.any?

      [
        IssueDto.new(key: "open_enrollment_ready", title: "Open enrollment is Vitable-ready", detail: "Employee elections, dependent records, and plan catalog are ready for eligibility generation.", severity: "low", status: "ready", owner: "Benefits", count: invitations.count, action_path: routes.generate_benefits_eligibility_batch_path)
      ]
    end
  end
end
