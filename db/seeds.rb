organization = Organization.find_or_initialize_by(external_id: "org_demo_vitable")
organization.assign_attributes(
  name: "Northstar People Ops",
  status: "active",
  metadata: { segment: "mid_market", source: "seed" }
)
organization.save!

connection = organization.integration_connections.find_or_initialize_by(provider: "vitable", environment: "production")
connection.assign_attributes(
  api_key_reference: "VITABLE_CONNECT_API_KEY",
  webhook_secret_reference: "VITABLE_WEBHOOK_SECRET",
  status: ENV["VITABLE_CONNECT_API_KEY"].present? ? "active" : "needs_credentials",
  metadata: { docs: "https://developer.vitablehealth.com/" }
)
connection.save!

employer = organization.employers.find_or_initialize_by(name: "Atlas Coffee Roasters")
employer.assign_attributes(
  legal_name: "Atlas Coffee Roasters LLC",
  ein: "12-3456789",
  status: "onboarding",
  onboarded_at: 2.weeks.ago,
  settings: {
    pay_frequency: "biweekly",
    contribution_strategy: "fixed_employer_contribution",
    enrollment_widget: "embedded",
    payroll_provider: "musto_payroll"
  }
)
employer.save!

organization.employers.find_or_initialize_by(name: "Lumen Field Services").tap do |record|
  record.assign_attributes(
    legal_name: "Lumen Field Services Inc.",
    ein: "87-6543210",
    status: "active",
    onboarded_at: 2.months.ago,
    settings: { pay_frequency: "semimonthly", enrollment_widget: "embedded" }
  )
  record.save!
end

departments = {
  "OPS" => [ "Operations", 1_150_000 ],
  "RET" => [ "Retail", 920_000 ],
  "PPL" => [ "People", 430_000 ],
  "FIN" => [ "Finance", 510_000 ]
}.to_h do |code, (name, budget_cents)|
  department = employer.departments.find_or_initialize_by(code:)
  department.assign_attributes(name:, budget_cents:, metadata: { planning_owner: "people_ops" })
  department.save!
  [ code, department ]
end

locations = {
  "Philadelphia HQ" => { city: "Philadelphia", state: "PA", address_line1: "214 Market Street", remote: false },
  "Denver Roastery" => { city: "Denver", state: "CO", address_line1: "88 Blake Street", remote: false },
  "Remote US" => { city: nil, state: nil, address_line1: nil, remote: true }
}.to_h do |name, attrs|
  location = employer.work_locations.find_or_initialize_by(name:)
  location.assign_attributes(attrs.merge(country: "US", metadata: { tax_profile: attrs[:remote] ? "multi_state" : "single_state" }))
  location.save!
  [ name, location ]
end

employees = [
  [ "Avery", "Kim", "avery.kim@example.com", "1990-04-11", "Head of Operations", "OPS", "Philadelphia HQ", 132_000_00, "complete" ],
  [ "Jordan", "Lee", "jordan.lee@example.com", "1987-09-23", "Retail Lead", "RET", "Philadelphia HQ", 86_000_00, "in_progress" ],
  [ "Morgan", "Patel", "morgan.patel@example.com", "1995-01-18", "People Partner", "PPL", "Remote US", 92_000_00, "complete" ],
  [ "Riley", "Chen", "riley.chen@example.com", "1992-12-02", "Payroll Analyst", "FIN", "Remote US", 98_000_00, "in_progress" ],
  [ "Sam", "Rivera", "sam.rivera@example.com", "1989-05-06", "Roastery Manager", "OPS", "Denver Roastery", 104_000_00, "blocked" ],
  [ "Taylor", "Brooks", "taylor.brooks@example.com", "1998-08-17", "Cafe Associate", "RET", "Denver Roastery", 54_000_00, "complete" ]
].map do |first_name, last_name, email, date_of_birth, title, department_code, location_name, compensation_cents, onboarding_status|
  employee = employer.employees.find_or_initialize_by(email:)
  employee.assign_attributes(
    first_name:,
    last_name:,
    date_of_birth:,
    title:,
    department: departments.fetch(department_code),
    work_location: locations.fetch(location_name),
    compensation_cents:,
    pay_type: title.include?("Associate") ? "hourly" : "salary",
    start_on: Date.current - rand(20..420).days,
    employment_status: "active",
    onboarding_status:,
    metadata: { source: "seed", vitable_sync_strategy: "upsert" }
  )
  employee.save!
  employee
end

departments["OPS"].update!(manager: employees.first)
departments["RET"].update!(manager: employees.second)
departments["PPL"].update!(manager: employees.third)
departments["FIN"].update!(manager: employees.fourth)

plans = [
  [ "Vitable Direct Primary Care", "direct_primary_care", "Vitable", 9_900 ],
  [ "Minimum Essential Coverage", "minimum_essential_coverage", "Vitable", 14_900 ],
  [ "Dental + Vision", "dental_vision", "Vitable", 7_500 ],
  [ "ICHRA Marketplace", "ichra", "Vitable", 28_500 ]
].to_h do |name, category, carrier, monthly_premium_cents|
  plan = employer.benefit_plans.find_or_initialize_by(name:)
  plan.assign_attributes(category:, carrier:, status: "available", monthly_premium_cents:)
  plan.save!
  [ category, plan ]
end

employees.each_with_index do |employee, index|
  plans.values.each_with_index do |plan, plan_index|
    enrollment = employee.enrollments.find_or_initialize_by(benefit_plan: plan)
    accepted = index.even? || plan_index.zero?
    enrollment.assign_attributes(
      status: accepted ? "accepted" : "pending",
      coverage_level: index == 0 ? "employee_family" : "employee",
      effective_on: Date.current.beginning_of_month.next_month,
      accepted_at: accepted ? (Time.current - index.days) : nil,
      metadata: { embedded_widget_session: "demo_session_#{employee.id}_#{plan.id}" }
    )
    enrollment.save!
  end
end

employees.each do |employee|
  [
    [ "Complete I-9 verification", "identity", employee.onboarding_status == "blocked" ? "open" : "complete", Date.current - 2.days, "people" ],
    [ "Review benefits enrollment", "benefits", employee.enrollments.pending.exists? ? "open" : "complete", Date.current + 3.days, "benefits" ],
    [ "Confirm payroll tax setup", "payroll", employee.onboarding_status == "complete" ? "complete" : "open", Date.current + 5.days, "payroll" ]
  ].each do |title, category, status, due_on, owner|
    task = employee.onboarding_tasks.find_or_initialize_by(title:)
    task.assign_attributes(category:, status:, due_on:, owner:, completed_at: status == "complete" ? 1.day.ago : nil)
    task.save!
  end
end

employees.each_with_index do |employee, index|
  [
    [ "Form I-9", "identity", index == 4 ? "pending" : "complete", nil ],
    [ "W-4", "tax", "complete", nil ],
    [ "Benefits disclosure", "benefits", index == 1 ? "pending" : "complete", Date.current + 45.days ]
  ].each do |title, document_type, status, expires_on|
    document = employee.employee_documents.find_or_initialize_by(title:)
    document.assign_attributes(document_type:, status:, issued_on: Date.current - 20.days, expires_on:)
    document.save!
  end
end

pto = employer.time_off_policies.find_or_initialize_by(name: "Flexible PTO")
pto.assign_attributes(accrual_method: "annual_grant", annual_hours: 160, carryover_hours: 40, paid: true, status: "active")
pto.save!

sick = employer.time_off_policies.find_or_initialize_by(name: "Sick Leave")
sick.assign_attributes(accrual_method: "state_accrual", annual_hours: 56, carryover_hours: 24, paid: true, status: "active")
sick.save!

[
  [ employees.second, pto, Date.current + 8.days, Date.current + 10.days, 24, "requested", "Family travel" ],
  [ employees.fourth, sick, Date.current + 3.days, Date.current + 3.days, 8, "approved", "Medical appointment" ],
  [ employees.last, pto, Date.current + 21.days, Date.current + 22.days, 16, "requested", "Long weekend" ]
].each do |employee, policy, starts_on, ends_on, hours, status, reason|
  request = employee.time_off_requests.find_or_initialize_by(time_off_policy: policy, starts_on:)
  request.assign_attributes(ends_on:, hours:, status:, reason:, reviewed_at: status == "requested" ? nil : 1.day.ago)
  request.save!
end

current_run = employer.payroll_runs.find_or_initialize_by(
  period_start_on: Date.current.beginning_of_month,
  period_end_on: Date.current.end_of_month,
  pay_date: Date.current.end_of_month
)
current_run.assign_attributes(status: "estimated", gross_pay_cents: employees.sum(&:compensation_cents) / 24)
current_run.save!

previous_run = employer.payroll_runs.find_or_initialize_by(
  period_start_on: 1.month.ago.to_date.beginning_of_month,
  period_end_on: 1.month.ago.to_date.end_of_month,
  pay_date: 1.month.ago.to_date.end_of_month
)
previous_run.assign_attributes(status: "finalized", gross_pay_cents: employees.sum(&:compensation_cents) / 24)
previous_run.save!

employees.each do |employee|
  current_run.payroll_deductions.find_or_initialize_by(employee:, code: "VITABLE_BENEFITS").tap do |deduction|
    accepted_enrollment = employee.enrollments.accepted.first
    deduction.assign_attributes(
      enrollment: accepted_enrollment,
      amount_cents: accepted_enrollment.present? ? accepted_enrollment.benefit_plan.monthly_premium_cents : 0,
      status: accepted_enrollment.present? ? "ready" : "waiting_on_enrollment"
    )
    deduction.save!
  end
end

[
  [ employees.first, "bonus", 2_500_00, "Quarterly operations bonus", true ],
  [ employees.third, "reimbursement", 340_00, "Home office stipend", false ],
  [ employees.last, "correction", -120_00, "Prior period correction", true ]
].each do |employee, adjustment_type, amount_cents, description, taxable|
  adjustment = current_run.payroll_adjustments.find_or_initialize_by(employee:, description:)
  adjustment.assign_attributes(adjustment_type:, amount_cents:, taxable:)
  adjustment.save!
end

employees.each_with_index do |employee, employee_index|
  4.times do |day_offset|
    work_date = current_run.period_start_on + day_offset.days
    entry = employee.time_entries.find_or_initialize_by(work_date:, source: "web")
    clock_in_at = work_date.in_time_zone.change(hour: 9, min: 0) + employee_index.minutes
    clock_out_at = clock_in_at + (employee.pay_type == "hourly" ? 9.hours : 8.hours)
    entry.assign_attributes(
      clock_in_at:,
      clock_out_at:,
      break_minutes: employee.pay_type == "hourly" ? 45 : 30,
      status: day_offset == 3 && employee_index.odd? ? "submitted" : "approved",
      approved_at: day_offset == 3 && employee_index.odd? ? nil : 1.day.ago,
      reviewed_at: day_offset == 3 && employee_index.odd? ? nil : 1.day.ago,
      notes: day_offset == 3 && employee_index.odd? ? "Manager review needed before export" : "Regular shift",
      metadata: { import_source: "seeded_clock" }
    )
    entry.save!
  end
end

contractors = [
  [ "Devon", "Stone", "devon.stone@example.com", "Stone Ops LLC", "company", "active", "complete", "verified", 9_500 ],
  [ "Kai", "Mendez", "kai.mendez@example.com", nil, "individual", "onboarding", "missing", "missing", 7_500 ],
  [ "Priya", "Shah", "priya.shah@example.com", "Shah Compliance Studio", "company", "active", "complete", "verified", 12_000 ]
].map do |first_name, last_name, email, business_name, contractor_type, status, tax_form_status, payment_method_status, hourly_rate_cents|
  contractor = employer.contractors.find_or_initialize_by(email:)
  contractor.assign_attributes(
    first_name:,
    last_name:,
    business_name:,
    contractor_type:,
    status:,
    tax_form_status:,
    payment_method_status:,
    hourly_rate_cents:,
    start_on: Date.current - rand(10..180).days,
    metadata: { source: "seed", contractor_portal: "invite_sent" }
  )
  contractor.save!
  contractor
end

[
  [ contractors.first, "Benefits implementation sprint", current_run.period_start_on, current_run.period_end_on, current_run.pay_date, 4_200_00, "draft" ],
  [ contractors.second, "Open onboarding support", current_run.period_start_on, current_run.period_start_on + 7.days, current_run.pay_date, 1_200_00, "draft" ],
  [ contractors.third, "ACA filing advisory", current_run.period_start_on, current_run.period_end_on, current_run.pay_date + 2.days, 2_800_00, "approved" ]
].each do |contractor, description, work_period_start_on, work_period_end_on, pay_date, amount_cents, status|
  payment = contractor.contractor_payments.find_or_initialize_by(description:, pay_date:)
  payment.assign_attributes(
    work_period_start_on:,
    work_period_end_on:,
    amount_cents:,
    status:,
    payment_method: "ach",
    approved_at: status == "approved" ? 1.day.ago : nil,
    metadata: { source: "seeded_invoice" }
  )
  payment.save!
end

[
  [ employees[4], "i9_reverification", "critical", "open", Date.current + 2.days, "I-9 document still pending for Denver manager." ],
  [ nil, "aca_measurement_period", "high", "open", Date.current + 9.days, "ACA measurement period needs review before the next benefits export." ],
  [ employees[1], "state_tax_registration", "medium", "open", Date.current + 20.days, "Confirm PA local tax setup after location change." ]
].each do |employee, kind, severity, status, due_on, description|
  compliance_case = employer.compliance_cases.find_or_initialize_by(employee:, kind:)
  compliance_case.assign_attributes(severity:, status:, due_on:, description:)
  compliance_case.save!
end

[
  [ "wevt_demo_enrollment_accepted", "enrollment.accepted", "enrollment", "enrl_demo_accepted", "needs_credentials", 2.hours.ago ],
  [ "wevt_demo_employee_created", "employee.created", "employee", "empl_demo_created", "needs_credentials", 90.minutes.ago ],
  [ "wevt_demo_payroll_deduction", "payroll_deduction.generated", "payroll_deduction", "pded_demo_generated", "received", 25.minutes.ago ]
].each do |event_id, event_name, resource_type, resource_id, status, occurred_at|
  event = WebhookEvent.find_or_initialize_by(event_id:)
  event.assign_attributes(
    integration_connection: connection,
    organization_external_id: organization.external_id,
    event_name:,
    resource_type:,
    resource_id:,
    occurred_at:,
    status:,
    payload: {
      event_id:,
      organization_id: organization.external_id,
      event_name:,
      resource_type:,
      resource_id:,
      created_at: occurred_at.iso8601
    }
  )
  event.save!
end
