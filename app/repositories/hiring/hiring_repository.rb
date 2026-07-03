module Hiring
  class HiringRepository < ApplicationRepository
    def initialize(employer: nil)
      @employer = employer
    end

    def job_openings
      return JobOpening.none unless @employer

      @employer
        .job_openings
        .includes(:department, :work_location, :candidates)
        .current_first
    end

    def candidates
      return Candidate.none unless @employer

      Candidate
        .joins(:job_opening)
        .where(job_openings: { employer_id: @employer.id })
        .includes(:employee, job_opening: [ :department, :work_location ])
        .order(stage: :asc, score: :desc, applied_on: :asc)
    end

    def batches
      payload = @employer&.settings.to_h.fetch("hiring_onboarding_handoff", nil)
      payload.present? ? [ payload ] : []
    end

    def find_candidate(id)
      scope = Candidate.includes(:employee, job_opening: [ :employer, :department, :work_location ])
      scope = scope.joins(:job_opening).where(job_openings: { employer_id: @employer.id }) if @employer
      scope.find(id)
    end

    def send_offer(candidate, offered_by:)
      return false unless candidate.offerable?

      candidate.update!(
        stage: "offer",
        offer_sent_at: Time.current,
        metadata: candidate.metadata.to_h.merge(
          "offered_by" => offered_by,
          "offer_sent_at" => Time.current.iso8601,
          "offer_channel" => "candidate_portal"
        )
      )
    end

    def generate_onboarding_handoff(requested_by:)
      accepted_candidates = candidates.accepted.to_a
      lines = []
      holdbacks = []

      if accepted_candidates.empty?
        holdbacks << empty_holdback("No accepted candidates are ready for onboarding handoff")
      end

      accepted_candidates.each do |candidate|
        if candidate.employee&.onboarding_status == "complete"
          holdbacks << holdback_line(candidate, reason: "Candidate is already linked to a completed employee profile")
          next
        end

        employee = employee_for(candidate)
        tasks = ensure_onboarding_tasks(employee, candidate)
        candidate.update!(
          employee:,
          stage: "hired",
          hired_at: Time.current,
          metadata: candidate.metadata.to_h.merge(
            "hired_by" => requested_by,
            "hired_at" => Time.current.iso8601,
            "onboarding_task_ids" => tasks.map(&:id)
          )
        )
        lines << handoff_line(candidate, employee, tasks)
      end

      batch = batch_payload(lines:, holdbacks:, requested_by:)
      @employer.update!(settings: @employer.settings.to_h.merge("hiring_onboarding_handoff" => batch))
      batch
    end

    private

    def employee_for(candidate)
      opening = candidate.job_opening
      employee = @employer.employees.find_or_initialize_by(email: candidate.email)
      employee.assign_attributes(
        first_name: candidate.first_name,
        last_name: candidate.last_name,
        title: opening.title,
        department: opening.department,
        work_location: opening.work_location,
        compensation_cents: candidate.compensation_cents,
        pay_type: opening.employment_type == "part_time" ? "hourly" : "salary",
        start_on: candidate.target_start_on || opening.target_start_on || 14.days.from_now.to_date,
        employment_status: "active",
        onboarding_status: "in_progress",
        metadata: employee.metadata.to_h.merge(
          "source" => "hiring_onboarding_handoff",
          "candidate_id" => candidate.id,
          "job_opening_id" => opening.id
        )
      )
      employee.save!
      employee
    end

    def ensure_onboarding_tasks(employee, candidate)
      due_on = employee.start_on || 14.days.from_now.to_date
      [
        [ "Sign offer and policy packet", "policy", "People Ops", due_on - 7.days ],
        [ "Complete I-9 and tax setup", "compliance", "Employee", due_on - 5.days ],
        [ "Add direct deposit details", "payroll", "Employee", due_on - 4.days ],
        [ "Choose Vitable benefits coverage", "benefits", "Benefits", due_on - 2.days ]
      ].map do |title, category, owner, task_due_on|
        employee.onboarding_tasks.find_or_initialize_by(title:).tap do |task|
          task.assign_attributes(
            category:,
            owner:,
            due_on: task_due_on,
            status: task.status.presence || "pending",
            metadata: task.metadata.to_h.merge(
              "source" => "hiring_onboarding_handoff",
              "candidate_id" => candidate.id
            )
          )
          task.save!
        end
      end
    end

    def batch_payload(lines:, holdbacks:, requested_by:)
      {
        "batch_id" => "hiring_onboarding_#{@employer.id}_#{Time.current.to_i}",
        "generated_at" => Time.current.iso8601,
        "requested_by" => requested_by,
        "employer_id" => @employer.id,
        "status" => lines.any? && holdbacks.empty? ? "ready" : "needs_review",
        "totals" => {
          "hire_count" => lines.count,
          "task_count" => lines.sum { |line| line.fetch("task_count") },
          "holdback_count" => holdbacks.count
        },
        "lines" => lines,
        "holdbacks" => holdbacks
      }
    end

    def handoff_line(candidate, employee, tasks)
      {
        "candidate_id" => candidate.id,
        "employee_id" => employee.id,
        "candidate_name" => candidate.full_name,
        "job_title" => candidate.job_opening.title,
        "department_name" => candidate.job_opening.department&.name,
        "start_on" => employee.start_on.iso8601,
        "task_count" => tasks.count,
        "status" => "hired"
      }
    end

    def holdback_line(candidate, reason:)
      {
        "candidate_id" => candidate.id,
        "candidate_name" => candidate.full_name,
        "job_title" => candidate.job_opening.title,
        "reason" => reason,
        "status" => candidate.stage
      }
    end

    def empty_holdback(reason)
      {
        "candidate_id" => nil,
        "candidate_name" => "Hiring pipeline",
        "job_title" => "Accepted candidates",
        "reason" => reason,
        "status" => "needs_review"
      }
    end
  end
end
