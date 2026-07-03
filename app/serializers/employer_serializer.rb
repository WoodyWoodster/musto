class EmployerSerializer
  def initialize(employer)
    @employer = employer
  end

  def as_json(*)
    {
      id: @employer.id,
      organization_id: @employer.organization_id,
      vitable_id: @employer.vitable_id,
      name: @employer.name,
      legal_name: @employer.legal_name,
      ein: @employer.ein,
      status: @employer.status,
      onboarded_at: @employer.onboarded_at,
      counts: {
        employees: @employer.employees.count,
        benefit_plans: @employer.benefit_plans.count,
        enrollments: @employer.enrollments.count,
        payroll_runs: @employer.payroll_runs.count
      }
    }
  end
end
