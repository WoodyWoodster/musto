module Hiring
  class CenterQuery
    STAGES = %w[applied screening interview offer accepted hired rejected withdrawn].freeze

    def initialize(employer_repository: Employers::EmployerRepository.new)
      @employer = employer_repository.first_for_operations
      @repository = HiringRepository.new(employer: @employer)
    end

    def call
      openings = @repository.job_openings.to_a
      candidates = @repository.candidates.to_a
      batches = @repository.batches
      latest_batch = batches.first.to_h

      CenterDto.new(
        employer: Operations::EmployerContextDto.from_record(@employer),
        metrics: metrics(openings, candidates),
        job_openings: openings.map { |opening| JobOpeningDto.from_record(opening) },
        candidates: candidates.map { |candidate| CandidateDto.from_record(candidate) },
        pipeline_stages: pipeline_stages(candidates),
        issues: issues(openings, candidates),
        handoff_batches: batches.map { |payload| HandoffBatchDto.from_hash(payload) },
        handoff_lines: latest_batch.fetch("lines", []).map { |payload| HandoffLineDto.from_hash(payload) },
        handoff_holdbacks: latest_batch.fetch("holdbacks", []).map { |payload| HandoffHoldbackDto.from_hash(payload) },
        handoff_payload: batches.first
      )
    end

    private

    def metrics(openings, candidates)
      open_roles = openings.count(&:open?)
      active_candidates = candidates.count { |candidate| !candidate.inactive? }
      offers_out = candidates.count { |candidate| candidate.stage == "offer" }
      accepted = candidates.count(&:accepted?)

      [
        MetricDto.new(label: "Open roles", value: open_roles, hint: "#{openings.count} total job openings", status: open_roles.positive? ? "active" : "needs_review", accent: "bg-indigo-500", format: "number"),
        MetricDto.new(label: "Active candidates", value: active_candidates, hint: "#{candidates.count} candidate records", status: active_candidates.positive? ? "in_progress" : "needs_review", accent: "bg-cyan-500", format: "number"),
        MetricDto.new(label: "Offers out", value: offers_out, hint: "awaiting acceptance", status: offers_out.positive? ? "needs_review" : "ready", accent: "bg-amber-500", format: "number"),
        MetricDto.new(label: "Accepted hires", value: accepted, hint: "ready for onboarding handoff", status: accepted.positive? ? "ready" : "in_progress", accent: "bg-emerald-500", format: "number")
      ]
    end

    def pipeline_stages(candidates)
      grouped = candidates.group_by(&:stage)

      STAGES.map do |stage|
        stage_candidates = grouped.fetch(stage, [])
        top_candidate = stage_candidates.max_by(&:score)

        PipelineStageDto.new(
          stage:,
          label: stage.humanize,
          candidate_count: stage_candidates.count,
          top_candidate_name: top_candidate&.full_name || "No candidates",
          status: stage_status(stage, stage_candidates)
        )
      end
    end

    def issues(openings, candidates)
      routes = Rails.application.routes.url_helpers
      items = []
      open_roles = openings.select(&:open?)
      accepted = candidates.select(&:accepted?)
      offers = candidates.select { |candidate| candidate.stage == "offer" }
      stalled = candidates.select { |candidate| !candidate.inactive? && candidate.applied_on < 21.days.ago.to_date }
      missing_compensation = candidates.select { |candidate| candidate.stage.in?(%w[offer accepted]) && candidate.compensation_cents.zero? }

      if open_roles.empty?
        items << IssueDto.new(key: "no_open_roles", title: "Open a hiring plan", detail: "At least one open job is needed before the hiring pipeline can drive onboarding.", severity: "medium", status: "needs_review", owner: "People Ops", count: openings.count, action_path: routes.hiring_path)
      end

      if accepted.any?
        items << IssueDto.new(key: "accepted_handoff", title: "Generate onboarding handoff", detail: "#{pluralized_count(accepted.count, "accepted candidate")} #{be_verb(accepted.count)} ready to become employees with onboarding tasks.", severity: "high", status: "ready", owner: "People Ops", count: accepted.count, action_path: routes.hiring_path)
      end

      if offers.any?
        items << IssueDto.new(key: "offers_pending", title: "Follow up on offers", detail: "#{pluralized_count(offers.count, "offer")} #{be_verb(offers.count)} out and waiting on candidate acceptance.", severity: "medium", status: "needs_review", owner: "Recruiting", count: offers.count, action_path: routes.hiring_path)
      end

      if stalled.any?
        items << IssueDto.new(key: "stalled_pipeline", title: "Refresh stalled candidates", detail: "#{pluralized_count(stalled.count, "active candidate")} #{have_verb(stalled.count)} been in process for more than 21 days.", severity: "medium", status: "needs_review", owner: "Hiring managers", count: stalled.count, action_path: routes.hiring_path)
      end

      if missing_compensation.any?
        items << IssueDto.new(key: "missing_compensation", title: "Add offer compensation", detail: "#{pluralized_count(missing_compensation.count, "offer-stage candidate")} #{need_verb(missing_compensation.count)} compensation before onboarding handoff.", severity: "high", status: "blocked", owner: "People Ops", count: missing_compensation.count, action_path: routes.compensation_path)
      end

      return items if items.any?

      [
        IssueDto.new(key: "hiring_ready", title: "Hiring pipeline is healthy", detail: "Open roles, offer follow-up, and onboarding handoffs are moving without blockers.", severity: "low", status: "ready", owner: "People Ops", count: candidates.count, action_path: routes.hiring_path)
      ]
    end

    def stage_status(stage, candidates)
      return "ready" if stage.in?(%w[hired rejected withdrawn]) && candidates.any?
      return "active" if candidates.any?

      "empty"
    end

    def pluralized_count(count, noun)
      "#{count} #{noun.pluralize(count)}"
    end

    def be_verb(count)
      count == 1 ? "is" : "are"
    end

    def have_verb(count)
      count == 1 ? "has" : "have"
    end

    def need_verb(count)
      count == 1 ? "needs" : "need"
    end
  end
end
