module Training
  class TrainingRepository < ApplicationRepository
    def initialize(employer: nil)
      @employer = employer
    end

    def programs
      return TrainingProgram.none unless @employer

      @employer.training_programs.includes(:training_assignments).current_first
    end

    def assignments
      return TrainingAssignment.none unless @employer

      TrainingAssignment
        .joins(:training_program)
        .where(training_programs: { employer_id: @employer.id })
        .includes(:training_program, employee: [ :department, :work_location ])
        .order(status: :asc, due_on: :asc, created_at: :desc)
    end

    def batches
      payload = @employer&.settings.to_h.fetch("training_audit_packet", nil)
      payload.present? ? [ payload ] : []
    end

    def current_program
      programs.active_or_draft.order(due_on: :asc, created_at: :desc).first || programs.first
    end

    def find_assignment(id)
      scope = TrainingAssignment.includes(:training_program, employee: [ :employer, :department, :work_location ])
      scope = scope.joins(:training_program).where(training_programs: { employer_id: @employer.id }) if @employer
      scope.find(id)
    end

    def launch_program(requested_by:)
      program = programs.where(status: "draft").order(due_on: :asc).first || build_default_program
      employees = @employer.employees.active.includes(:department, :work_location).to_a

      TrainingProgram.transaction do
        program.launch!(requested_by:) unless program.active?
        employees.each { |employee| ensure_assignment(program, employee) }
        program.refresh_counts!
      end

      program
    end

    def complete_assignment(assignment, completed_by:, score: nil)
      TrainingAssignment.transaction do
        assignment.complete!(completed_by:, score:)
        assignment.training_program.refresh_counts!
      end
    end

    def generate_audit_packet(requested_by:)
      records = assignments.to_a
      ready_assignments = records.select { |assignment| assignment.complete? && assignment.certificate_id.present? }
      holdback_assignments = records.reject { |assignment| assignment.complete? && assignment.certificate_id.present? }
      lines = ready_assignments.map { |assignment| audit_line(assignment) }
      holdbacks = holdback_assignments.map { |assignment| holdback_line(assignment) }
      holdbacks << empty_holdback("No certificate-ready training records are available") if lines.empty?
      batch = batch_payload(lines:, holdbacks:, requested_by:)

      TrainingAssignment.transaction do
        @employer.update!(settings: @employer.settings.to_h.merge("training_audit_packet" => batch))
        programs.where(status: "active").find_each do |program|
          program.refresh_counts!
          program.update!(status: "closed", closed_at: Time.current) if program.required_count.positive? && program.required_count == program.completed_count
        end
      end

      batch
    end

    private

    def build_default_program
      @employer.training_programs.create!(
        title: "Annual compliance essentials",
        category: "compliance",
        description: "Required handbook, harassment prevention, workplace safety, and benefits policy attestations.",
        audience: "all_employees",
        cadence: "annual",
        launch_on: Date.current,
        due_on: Date.current + 21.days,
        metadata: { "source" => "training_center" }
      )
    end

    def ensure_assignment(program, employee)
      program.training_assignments.find_or_initialize_by(employee:).tap do |assignment|
        assignment.assign_attributes(
          status: assignment.status.presence || "assigned",
          due_on: assignment.due_on || program.due_on,
          metadata: assignment.metadata.to_h.merge(
            "source" => "training_program_launch",
            "launched_at" => Time.current.iso8601
          )
        )
        assignment.save!
      end
    end

    def batch_payload(lines:, holdbacks:, requested_by:)
      scores = lines.filter_map { |line| line.fetch("score", nil) }

      {
        "batch_id" => "training_audit_#{@employer.id}_#{Time.current.to_i}",
        "generated_at" => Time.current.iso8601,
        "requested_by" => requested_by,
        "employer_id" => @employer.id,
        "status" => lines.any? && holdbacks.empty? ? "ready" : "needs_review",
        "totals" => {
          "assignment_count" => lines.count,
          "employee_count" => lines.map { |line| line.fetch("employee_id") }.uniq.count,
          "holdback_count" => holdbacks.count,
          "average_score" => scores.any? ? (scores.sum.to_f / scores.count).round(1) : 0
        },
        "assignments" => lines,
        "holdbacks" => holdbacks
      }
    end

    def audit_line(assignment)
      {
        "assignment_id" => assignment.id,
        "employee_id" => assignment.employee_id,
        "employee_name" => assignment.employee.full_name,
        "program_title" => assignment.training_program.title,
        "category" => assignment.training_program.category,
        "completed_at" => assignment.completed_at&.iso8601,
        "score" => assignment.score,
        "certificate_id" => assignment.certificate_id,
        "status" => "certificate_ready"
      }
    end

    def holdback_line(assignment)
      {
        "assignment_id" => assignment.id,
        "employee_name" => assignment.employee.full_name,
        "program_title" => assignment.training_program.title,
        "status" => assignment.overdue? ? "overdue" : assignment.status,
        "reason" => holdback_reason(assignment)
      }
    end

    def holdback_reason(assignment)
      return "Training assignment is overdue" if assignment.overdue?
      return "Completed assignment is missing a certificate reference" if assignment.complete?

      "Employee has not completed the training assignment"
    end

    def empty_holdback(reason)
      {
        "assignment_id" => nil,
        "employee_name" => "Training program",
        "program_title" => "Compliance training",
        "status" => "needs_review",
        "reason" => reason
      }
    end
  end
end
