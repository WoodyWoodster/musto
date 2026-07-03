module PayrollCalendar
  CenterDto = Data.define(
    :employer,
    :schedule,
    :payroll_run,
    :metrics,
    :approval_steps,
    :calendar_events,
    :risks,
    :checklists,
    :checklist_lines,
    :checklist_payload
  ) do
    def latest_checklist
      checklists.first
    end

    def blocked_steps
      approval_steps.select(&:blocked?)
    end

    def incomplete_steps
      approval_steps.reject(&:completed?)
    end

    def ready_for_final_approval?
      risks.none? { |risk| risk.status == "blocked" } && blocked_steps.empty?
    end
  end
end
