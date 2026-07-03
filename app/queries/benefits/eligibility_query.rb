module Benefits
  class EligibilityQuery
    def initialize(employer_repository: Employers::EmployerRepository.new)
      @employer = employer_repository.first_for_operations
      @repository = EligibilityRepository.new(employer: @employer)
    end

    def call
      enrollments = @repository.enrollments.to_a
      dependents = @repository.dependents.to_a
      batches = @repository.batches
      latest_batch = batches.first.to_h

      EligibilityCenterDto.new(
        employer: Operations::EmployerContextDto.from_record(@employer),
        metrics: metrics(enrollments, dependents),
        members: enrollments.map { |enrollment| EligibilityMemberDto.from_enrollment(enrollment) },
        dependents: dependents.map { |dependent| EligibilityDependentDto.from_record(dependent) },
        issues: issues(enrollments, dependents),
        batches: batches.map { |payload| EligibilityBatchDto.from_hash(payload) },
        batch_members: latest_batch.fetch("members", []).map { |payload| EligibilityBatchMemberDto.from_hash(payload) },
        batch_holdbacks: latest_batch.fetch("holdbacks", []).map { |payload| EligibilityBatchHoldbackDto.from_hash(payload) },
        batch_payload: batches.first
      )
    end

    private

    def metrics(enrollments, dependents)
      accepted_count = enrollments.count { |enrollment| enrollment.status == "accepted" }
      eligible_dependents = dependents.count(&:eligible?)
      pending_enrollments = enrollments.count { |enrollment| enrollment.status == "pending" }
      remote_pending = enrollments.count { |enrollment| enrollment.employee.vitable_id.blank? || enrollment.vitable_id.blank? }

      [
        EligibilityMetricDto.new(label: "Accepted elections", value: accepted_count, hint: "#{enrollments.count} enrollment records", status: accepted_count.positive? ? "ready" : "needs_review", accent: "bg-cyan-500", format: "number"),
        EligibilityMetricDto.new(label: "Eligible dependents", value: eligible_dependents, hint: "#{dependents.count} dependent profiles", status: eligible_dependents == dependents.count ? "ready" : "needs_review", accent: "bg-emerald-500", format: "number"),
        EligibilityMetricDto.new(label: "Pending elections", value: pending_enrollments, hint: "need employee action", status: pending_enrollments.positive? ? "needs_review" : "ready", accent: "bg-amber-500", format: "number"),
        EligibilityMetricDto.new(label: "Remote IDs pending", value: remote_pending, hint: "will be created or matched on sync", status: remote_pending.positive? ? "remote_pending" : "synced", accent: "bg-indigo-500", format: "number")
      ]
    end

    def issues(enrollments, dependents)
      routes = Rails.application.routes.url_helpers
      items = []
      pending_enrollments = enrollments.count { |enrollment| enrollment.status == "pending" }
      missing_effective_dates = enrollments.count { |enrollment| enrollment.status == "accepted" && enrollment.effective_on.blank? }
      dependent_reviews = dependents.count { |dependent| !dependent.eligible? }
      remote_pending = enrollments.count { |enrollment| enrollment.employee.vitable_id.blank? || enrollment.vitable_id.blank? }

      if pending_enrollments.positive?
        items << EligibilityIssueDto.new(key: "pending_enrollments", title: "Resolve pending benefit elections", detail: "#{pending_enrollments} enrollments need acceptance or waiver before eligibility sync.", severity: "medium", status: "needs_review", owner: "Benefits", action_path: routes.benefits_path)
      end

      if missing_effective_dates.positive?
        items << EligibilityIssueDto.new(key: "missing_effective_dates", title: "Set effective dates", detail: "#{missing_effective_dates} accepted enrollments are missing effective dates.", severity: "high", status: "blocked", owner: "Benefits", action_path: routes.benefits_eligibility_path)
      end

      if dependent_reviews.positive?
        items << EligibilityIssueDto.new(key: "dependent_reviews", title: "Review dependent eligibility", detail: "#{dependent_reviews} dependent records need enrollment or eligibility review.", severity: "medium", status: "needs_review", owner: "People", action_path: routes.benefits_eligibility_path)
      end

      if remote_pending.positive?
        items << EligibilityIssueDto.new(key: "remote_ids", title: "Prepare remote member IDs", detail: "#{remote_pending} member or enrollment IDs will be matched or created when Vitable credentials are configured.", severity: "low", status: "remote_pending", owner: "Integrations", action_path: routes.integrations_path)
      end

      return items if items.any?

      [
        EligibilityIssueDto.new(key: "eligibility_ready", title: "Eligibility batch is ready", detail: "Accepted elections and dependent records are ready for the next Vitable member eligibility batch.", severity: "low", status: "ready", owner: "Benefits", action_path: routes.generate_benefits_eligibility_batch_path)
      ]
    end
  end
end
