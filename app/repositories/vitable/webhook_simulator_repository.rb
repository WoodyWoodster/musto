module Vitable
  class WebhookSimulatorRepository < ApplicationRepository
    def resource_ids(connection)
      employers = employer_scope(connection)
      employees = employee_scope(employers)
      enrollments = enrollment_scope(employers)
      dependents = dependent_scope(employers)
      deductions = payroll_deduction_scope(employers)
      snapshot_ids = snapshot_resource_ids(connection.metadata)

      {
        "enrollment" => first_present_id(
          enrollments.where.not(vitable_id: [ nil, "" ]).order(:id).pick(:vitable_id),
          snapshot_ids["enrollment"]
        ),
        "employee" => first_present_id(
          employees.where.not(vitable_id: [ nil, "" ]).order(:id).pick(:vitable_id),
          snapshot_ids["employee"]
        ),
        "payroll_deduction" => first_present_id(
          deductions.where.not(vitable_id: [ nil, "" ]).order(:id).pick(:vitable_id),
          snapshot_ids["payroll_deduction"]
        ),
        "dependent" => first_present_id(
          dependents.where.not(vitable_id: [ nil, "" ]).order(:id).pick(:vitable_id),
          snapshot_ids["dependent"]
        ),
        "employer" => first_present_id(
          employers.where.not(vitable_id: [ nil, "" ]).order(:id).pick(:vitable_id),
          snapshot_ids["employer"]
        ),
        "plan_year" => first_present_id(
          first_plan_year_snapshot_id(employers),
          snapshot_ids["plan_year"]
        ),
        "group" => first_present_id(
          employers.order(:id).filter_map { |employer| employer.settings.to_h.stringify_keys.fetch(CareGroupRepository::GROUP_ID_KEY, nil).presence }.first,
          snapshot_ids["group"]
        )
      }.compact
    end

    def payload(connection:, dto:)
      base_payload = dto.to_payload(connection.organization.external_id)
      resource_payload =
        case dto.resource_type
        when "dependent"
          dependent_payload(connection, dto)
        when "payroll_deduction"
          payroll_deduction_payload(connection, dto)
        when "plan_year"
          plan_year_payload(connection, dto)
        end

      resource_payload.present? ? base_payload.merge(data: resource_payload) : base_payload
    end

    private

    def dependent_payload(connection, dto)
      dependent = dependent_for(connection, dto.resource_id)
      return unless dependent

      employee = dependent.employee
      {
        id: dto.resource_id.presence || dependent.vitable_id,
        employee_id: employee.vitable_id,
        employee_reference_id: "musto_employee_#{employee.id}",
        employee_email: employee.email,
        first_name: dependent.first_name,
        last_name: dependent.last_name,
        relationship: dependent.relationship,
        date_of_birth: dependent.date_of_birth&.iso8601,
        status: dependent.enrollment_status == "waived" ? "inactive" : "active",
        eligibility_status: dependent.eligibility_status
      }.compact
    end

    def payroll_deduction_payload(connection, dto)
      deduction = payroll_deduction_for(connection, dto.resource_id)
      return unless deduction

      employee = deduction.employee
      enrollment = deduction.enrollment
      plan = enrollment&.benefit_plan

      {
        id: dto.resource_id.presence || deduction.vitable_id,
        employee_id: employee.vitable_id,
        reference_id: "musto_employee_#{employee.id}",
        email: employee.email,
        plan_id: plan&.vitable_id,
        enrollment_id: enrollment&.vitable_id,
        benefit_name: plan&.name || deduction.code,
        deduction_amount_in_cents: deduction.amount_cents,
        frequency: payroll_frequency(employee.employer),
        status: deduction.status == "ready" ? "active" : deduction.status
      }.compact
    end

    def plan_year_payload(connection, dto)
      employer = plan_year_employer_for(connection, dto.resource_id)
      return unless employer

      year = plan_year_for(employer, dto.resource_id)
      return if year.blank?

      plan = employer.benefit_plans.where(plan_year: year).order(:id).first
      campaign = employer.open_enrollment_campaigns.where(plan_year: year).order(:id).first

      {
        id: dto.resource_id,
        employer_id: employer.vitable_id,
        employer_reference_id: "musto_employer_#{employer.id}",
        year:,
        starts_on: (plan&.effective_on || Date.new(year, 1, 1)).iso8601,
        ends_on: (plan&.expires_on || Date.new(year, 12, 31)).iso8601,
        open_enrollment_starts_on: (campaign&.starts_on || Date.new(year - 1, 11, 1)).iso8601,
        open_enrollment_ends_on: (campaign&.ends_on || Date.new(year - 1, 11, 15)).iso8601,
        status: campaign&.status == "closed" ? "closed" : "active"
      }.compact
    end

    def dependent_for(connection, resource_id)
      dependents = dependent_scope(employer_scope(connection)).includes(:employee)
      dependents.find_by(vitable_id: resource_id) || dependents.order(:id).first
    end

    def payroll_deduction_for(connection, resource_id)
      deductions = payroll_deduction_scope(employer_scope(connection)).includes(:employee, enrollment: :benefit_plan)
      deductions.find_by(vitable_id: resource_id) || deductions.order(:id).first
    end

    def plan_year_employer_for(connection, resource_id)
      employers = employer_scope(connection)
      employers.where(vitable_id: resource_id).order(:id).first ||
        employers.order(:id).detect { |employer| plan_year_snapshot(employer, resource_id).present? } ||
        employers.order(:id).first
    end

    def plan_year_for(employer, resource_id)
      snapshot = plan_year_snapshot(employer, resource_id)
      snapshot.fetch("plan_year", nil).presence&.to_i ||
        snapshot.fetch("year", nil).presence&.to_i ||
        employer.benefit_plans.where.not(plan_year: nil).order(:plan_year).pick(:plan_year) ||
        employer.open_enrollment_campaigns.order(:plan_year).pick(:plan_year)
    end

    def payroll_frequency(employer)
      employer.settings.to_h.stringify_keys.fetch("pay_frequency", nil).presence || "biweekly"
    end

    def employer_scope(connection)
      Employer.where(organization_id: connection.organization_id)
    end

    def employee_scope(employers)
      Employee.where(employer_id: employers.select(:id))
    end

    def enrollment_scope(employers)
      Enrollment.joins(:employee).where(employees: { employer_id: employers.select(:id) })
    end

    def dependent_scope(employers)
      Dependent.joins(:employee).where(employees: { employer_id: employers.select(:id) })
    end

    def payroll_deduction_scope(employers)
      PayrollDeduction.joins(:employee).where(employees: { employer_id: employers.select(:id) })
    end

    def snapshot_resource_ids(metadata)
      snapshot = metadata.to_h.stringify_keys.fetch("api_snapshot", {}).to_h

      {
        "enrollment" => first_nested_remote_id(snapshot.fetch("employee_enrollments", []), "enrollments"),
        "employee" => first_nested_remote_id(snapshot.fetch("remote_employee_rosters", []), "employees"),
        "payroll_deduction" => first_present_id(
          first_nested_remote_id(snapshot.fetch("employee_enrollments", []), "payroll_deductions"),
          first_nested_remote_id(snapshot.fetch("remote_employee_rosters", []), "payroll_deductions")
        ),
        "dependent" => first_present_id(
          first_nested_remote_id(snapshot.fetch("employee_enrollments", []), "dependents"),
          first_nested_remote_id(snapshot.fetch("remote_employee_rosters", []), "dependents")
        ),
        "employer" => first_remote_id(snapshot.fetch("employers", [])),
        "plan_year" => first_remote_id(snapshot.fetch("plan_years", [])),
        "group" => first_remote_id(snapshot.fetch("groups", []))
      }.compact
    end

    def first_plan_year_snapshot_id(employers)
      employers.order(:id).filter_map do |employer|
        snapshots = plan_year_snapshots(employer)
        snapshots.values.filter_map { |snapshot| snapshot.to_h.stringify_keys.fetch("id", nil).presence }.first ||
          snapshots.keys.find(&:present?)
      end.first
    end

    def plan_year_snapshot(employer, resource_id)
      snapshots = plan_year_snapshots(employer)
      snapshots.fetch(resource_id, {}).to_h.stringify_keys
    end

    def plan_year_snapshots(employer)
      employer.settings.to_h.stringify_keys.fetch(PlanYearWebhookReconciliationRepository::SNAPSHOT_KEY, {}).to_h
    end

    def first_nested_remote_id(entries, collection_key)
      Array(entries).filter_map do |entry|
        first_remote_id(entry.to_h.stringify_keys.fetch(collection_key, []))
      end.first
    end

    def first_remote_id(records)
      Array(records).filter_map { |record| record.to_h.stringify_keys.fetch("id", nil).presence }.first
    end

    def first_present_id(*values)
      values.flatten.compact_blank.first
    end
  end
end
