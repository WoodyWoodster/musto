class DashboardQuery
  def initialize(
    employer_repository: Employers::EmployerRepository.new,
    employee_repository: Employees::EmployeeRepository.new,
    integration_repository: Vitable::IntegrationRepository.new,
    dashboard_repository: Dashboard::DashboardRepository.new
  )
    @employer_repository = employer_repository
    @employee_repository = employee_repository
    @integration_repository = integration_repository
    @dashboard_repository = dashboard_repository
  end

  def call
    {
      employer: Operations::EmployerContextDto.from_record(@employer_repository.first_for_operations),
      employers: @employer_repository.dashboard_portfolio.map { |employer| Employers::EmployerSummaryDto.from_record(employer) },
      active_employee_count: @employee_repository.active_count,
      payroll_ready_count: @employee_repository.payroll_ready_count,
      open_onboarding_count: @dashboard_repository.open_onboarding_count,
      pending_time_off_count: @dashboard_repository.pending_time_off_count,
      compliance_urgent_count: @dashboard_repository.urgent_compliance_count,
      benefits_participation_rate: @dashboard_repository.benefits_participation_rate,
      recent_activity: recent_activity,
      upcoming_payroll: Dashboard::PayrollPreviewDto.from_record(@dashboard_repository.upcoming_payroll),
      integration_health: @integration_repository.integration_health
    }
  end

  private

  def recent_activity
    @dashboard_repository.recent_activity.map do |type, title, status, timestamp|
      Dashboard::ActivityDto.new(type:, title:, status:, timestamp:)
    end
  end
end
