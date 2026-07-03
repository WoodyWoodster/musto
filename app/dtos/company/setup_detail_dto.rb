module Company
  SetupDetailDto = Data.define(
    :employer,
    :organization_name,
    :legal_name,
    :ein,
    :status,
    :onboarded_at,
    :launch_progress,
    :metrics,
    :steps,
    :payroll_settings,
    :departments,
    :locations,
    :integration,
    :coverage
  ) do
    def incomplete_steps
      steps.reject(&:complete?)
    end

    def critical_blockers
      steps.select(&:blocked?)
    end

    def ready_for_launch?
      critical_blockers.empty?
    end
  end
end
