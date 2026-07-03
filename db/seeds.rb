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
  vitable_id: "empr_atlas_demo",
  status: "onboarding",
  onboarded_at: 2.weeks.ago,
  settings: {
    pay_frequency: "biweekly",
    billing_email: "benefits@atlas.example",
    phone_number: "5551239000",
    contribution_strategy: "fixed_employer_contribution",
    enrollment_widget: "embedded",
    payroll_provider: "musto_payroll"
  }
)
employer.save!

primary_funding_account = employer.employer_bank_accounts.find_or_initialize_by(name: "Operating payroll account")
primary_funding_account.assign_attributes(
  institution_name: "Mercury Bank",
  account_type: "checking",
  routing_number_last4: "1101",
  account_last4: "4821",
  status: "verified",
  verification_method: "microdeposit",
  primary_account: true,
  verified_at: 3.days.ago,
  metadata: { source: "seed", funding_limit_cents: 950_000_00 }
)
primary_funding_account.save!

reserve_funding_account = employer.employer_bank_accounts.find_or_initialize_by(name: "Reserve funding account")
reserve_funding_account.assign_attributes(
  institution_name: "First Keystone",
  account_type: "savings",
  routing_number_last4: "2204",
  account_last4: "7710",
  status: "pending_verification",
  verification_method: "microdeposit",
  primary_account: false,
  verified_at: nil,
  metadata: { source: "seed", funding_limit_cents: 300_000_00 }
)
reserve_funding_account.save!

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
  "Philadelphia HQ" => { city: "Philadelphia", state: "PA", postal_code: "19106", address_line1: "214 Market Street", remote: false },
  "Denver Roastery" => { city: "Denver", state: "CO", postal_code: "80202", address_line1: "88 Blake Street", remote: false },
  "Remote US" => { city: nil, state: nil, address_line1: nil, remote: true }
}.to_h do |name, attrs|
  location = employer.work_locations.find_or_initialize_by(name:)
  location.assign_attributes(attrs.merge(country: "US", metadata: { tax_profile: attrs[:remote] ? "multi_state" : "single_state" }))
  location.save!
  [ name, location ]
end

[
  [
    nil,
    "Internal Revenue Service",
    "Federal",
    "federal_withholding",
    "12-3456789",
    "semiweekly",
    "registered",
    "low",
    Date.current - 90.days,
    60.days.ago,
    58.days.ago,
    "IRS-EFTPS-ATLAS",
    Date.current.next_month.change(day: 15),
    "Finance",
    "EFTPS profile is active for federal income tax, Social Security, and Medicare deposits."
  ],
  [
    locations.fetch("Philadelphia HQ"),
    "Pennsylvania Department of Revenue",
    "PA",
    "state_withholding",
    "PA-WH-908177",
    "semiweekly",
    "submitted",
    "medium",
    Date.current + 10.days,
    1.day.ago,
    nil,
    "PA-SUB-202607",
    Date.current.end_of_quarter + 30.days,
    "Payroll",
    "Withholding account submitted; unemployment rate assignment is pending agency confirmation."
  ],
  [
    locations.fetch("Denver Roastery"),
    "Colorado Department of Labor and Employment",
    "CO",
    "unemployment_insurance",
    nil,
    "registration_pending",
    "needs_review",
    "high",
    Date.current + 7.days,
    nil,
    nil,
    nil,
    nil,
    "Finance",
    "Colorado unemployment account needs wage-base review before the Denver team can be cleared."
  ],
  [
    locations.fetch("Remote US"),
    "Remote worker nexus review",
    "Multi-state",
    "remote_worker_nexus",
    nil,
    "manual_review",
    "blocked",
    "high",
    Date.current + 5.days,
    nil,
    nil,
    nil,
    nil,
    "Payroll",
    "Remote worker state registrations are blocked until employee work-state attestations are confirmed."
  ]
].each do |location, agency_name, jurisdiction, registration_type, account_number, deposit_schedule, status, risk_level, due_on, submitted_at, confirmed_at, confirmation_number, next_deposit_due_on, owner, notes|
  registration = employer.tax_agency_registrations.find_or_initialize_by(
    agency_name:,
    jurisdiction:,
    registration_type:
  )
  registration.assign_attributes(
    work_location: location,
    account_number:,
    deposit_schedule:,
    status:,
    risk_level:,
    due_on:,
    submitted_at:,
    confirmed_at:,
    confirmation_number:,
    next_deposit_due_on:,
    owner:,
    notes:,
    metadata: { source: "seeded_tax_agency_registration" }
  )
  registration.save!
end

employees = [
  [ "Avery", "Kim", "avery.kim@example.com", "1990-04-11", "5551231001", "empl_atlas_avery", "Head of Operations", "OPS", "Philadelphia HQ", 132_000_00, "complete" ],
  [ "Jordan", "Lee", "jordan.lee@example.com", "1987-09-23", "5551231002", "empl_atlas_jordan", "Retail Lead", "RET", "Philadelphia HQ", 86_000_00, "in_progress" ],
  [ "Morgan", "Patel", "morgan.patel@example.com", "1995-01-18", "5551231003", "empl_atlas_morgan", "People Partner", "PPL", "Remote US", 92_000_00, "complete" ],
  [ "Riley", "Chen", "riley.chen@example.com", "1992-12-02", "5551231004", nil, "Payroll Analyst", "FIN", "Remote US", 98_000_00, "in_progress" ],
  [ "Sam", "Rivera", "sam.rivera@example.com", "1989-05-06", "5551231005", nil, "Roastery Manager", "OPS", "Denver Roastery", 104_000_00, "blocked" ],
  [ "Taylor", "Brooks", "taylor.brooks@example.com", "1998-08-17", "5551231006", nil, "Cafe Associate", "RET", "Denver Roastery", 54_000_00, "complete" ]
].map do |first_name, last_name, email, date_of_birth, phone, vitable_id, title, department_code, location_name, compensation_cents, onboarding_status|
  employee = employer.employees.find_or_initialize_by(email:)
  employee.assign_attributes(
    first_name:,
    last_name:,
    date_of_birth:,
    vitable_id:,
    title:,
    department: departments.fetch(department_code),
    work_location: locations.fetch(location_name),
    compensation_cents:,
    pay_type: title.include?("Associate") ? "hourly" : "salary",
    start_on: Date.current - rand(20..420).days,
    employment_status: "active",
    onboarding_status:,
    metadata: { source: "seed", vitable_sync_strategy: "upsert", phone: }
  )
  employee.save!
  employee
end

departments["OPS"].update!(manager: employees.first)
departments["RET"].update!(manager: employees.second)
departments["PPL"].update!(manager: employees.third)
departments["FIN"].update!(manager: employees.fourth)

employees.second.update!(manager: employees.first, metadata: employees.second.metadata.to_h.merge(manager_assignment_source: "seed"))
employees.third.update!(manager: employees.first, metadata: employees.third.metadata.to_h.merge(manager_assignment_source: "seed"))
employees.fourth.update!(manager: employees.third, metadata: employees.fourth.metadata.to_h.merge(manager_assignment_source: "seed"))
employees[4].update!(manager: employees.first, metadata: employees[4].metadata.to_h.merge(manager_assignment_source: "seed"))
employees.last.update!(manager: employees.second, metadata: employees.last.metadata.to_h.merge(manager_assignment_source: "seed"))

job_openings = [
  [ "RET-GM-2026", "Retail General Manager", "RET", "Philadelphia HQ", "open", "full_time", 1, 92_000_00, 118_000_00, false, Date.current.next_month.beginning_of_month + 14.days, "Own Philadelphia retail operations and manager enablement." ],
  [ "FIN-PAY-2026", "Payroll Operations Specialist", "FIN", "Remote US", "open", "full_time", 1, 82_000_00, 98_000_00, true, Date.current.next_month.beginning_of_month + 21.days, "Run payroll controls, funding review, and Vitable deduction checks." ],
  [ "PPL-BEN-2026", "Benefits Implementation Lead", "PPL", "Remote US", "paused", "full_time", 1, 105_000_00, 132_000_00, true, Date.current.next_month.beginning_of_month + 28.days, "Coordinate onboarding, open enrollment, and Vitable implementation readiness." ]
].to_h do |code, title, department_code, location_name, status, employment_type, headcount, compensation_min_cents, compensation_max_cents, remote, target_start_on, description|
  opening = employer.job_openings.find_or_initialize_by(code:)
  opening.assign_attributes(
    title:,
    department: departments.fetch(department_code),
    work_location: locations.fetch(location_name),
    status:,
    employment_type:,
    headcount:,
    compensation_min_cents:,
    compensation_max_cents:,
    remote:,
    target_start_on:,
    description:,
    metadata: { source: "seeded_hiring_plan", recruiter: "people_ops" }
  )
  opening.save!
  [ code, opening ]
end

[
  [ "Nia", "Okafor", "nia.okafor.candidate@example.com", "referral", "interview", 94, "RET-GM-2026", 108_000_00, Date.current.next_month.beginning_of_month + 14.days, 11.days.ago.to_date ],
  [ "Miles", "Sato", "miles.sato.candidate@example.com", "linkedin", "offer", 88, "FIN-PAY-2026", 91_000_00, Date.current.next_month.beginning_of_month + 21.days, 18.days.ago.to_date ],
  [ "Priya", "Nair", "priya.nair.candidate@example.com", "direct", "accepted", 96, "PPL-BEN-2026", 124_000_00, Date.current.next_month.beginning_of_month + 28.days, 23.days.ago.to_date ],
  [ "Luca", "Marin", "luca.marin.candidate@example.com", "agency", "screening", 77, "RET-GM-2026", 101_000_00, Date.current.next_month.beginning_of_month + 18.days, 6.days.ago.to_date ],
  [ "Rhea", "Cole", "rhea.cole.candidate@example.com", "direct", "applied", 69, "FIN-PAY-2026", 86_000_00, Date.current.next_month.beginning_of_month + 30.days, 2.days.ago.to_date ]
].each do |first_name, last_name, email, source, stage, score, opening_code, compensation_cents, target_start_on, applied_on|
  candidate = job_openings.fetch(opening_code).candidates.find_or_initialize_by(email:)
  offer_sent_at = stage.in?([ "offer", "accepted" ]) ? 2.days.ago : nil
  candidate.assign_attributes(
    first_name:,
    last_name:,
    phone: "555-0199",
    source:,
    stage:,
    score:,
    applied_on:,
    target_start_on:,
    compensation_cents:,
    offer_sent_at:,
    accepted_at: stage == "accepted" ? 12.hours.ago : nil,
    metadata: { source: "seeded_candidate_pipeline", scorecard: "structured_interview" }
  )
  candidate.save!
end

[
  [ employees.first, "Primary checking", "Chase", "checking", "0210", "1842", "remainder", 100, "verified", "manual", true, 2.days.ago, nil ],
  [ employees.second, "Retail payroll", "Wells Fargo", "checking", "0821", "6640", "remainder", 100, "prenote_sent", "prenote", true, nil, 1.day.ago ],
  [ employees.third, "Remote checking", "Ally", "checking", "1040", "9088", "remainder", 100, "pending_verification", "microdeposit", true, nil, nil ],
  [ employees.fourth, "Finance savings", "Capital One", "savings", "3309", "4501", "percent", 100, "verified", "prenote", true, 4.days.ago, 5.days.ago ],
  [ employees[4], "Denver payroll", "US Bank", "checking", "5502", "2209", "remainder", 100, "blocked", "manual", true, nil, nil ],
  [ employees.last, "Pay card", "Branch", "pay_card", "7601", "5090", "remainder", 100, "verified", "manual", true, 1.day.ago, nil ]
].each do |employee, nickname, institution_name, account_type, routing_number_last4, account_last4, allocation_type, allocation_value, status, verification_method, primary_account, verified_at, prenote_sent_at|
  account = employee.employee_bank_accounts.find_or_initialize_by(nickname:)
  account.assign_attributes(
    institution_name:,
    account_type:,
    routing_number_last4:,
    account_last4:,
    allocation_type:,
    allocation_value:,
    status:,
    verification_method:,
    primary_account:,
    verified_at:,
    prenote_sent_at:,
    metadata: { source: "seeded_direct_deposit" }
  )
  account.save!
end

[
  [
    employees.second,
    "direct_deposit",
    "Replace primary direct deposit",
    "Jordan submitted a new primary checking account that needs prenote review before payroll funding.",
    "submitted",
    Date.current + 2.days,
    1.day.ago,
    {
      payload: {
        nickname: "New primary checking",
        institution_name: "SoFi Bank",
        account_type: "checking",
        routing_number_last4: "1188",
        account_last4: "6204",
        allocation_type: "remainder",
        allocation_value: 100
      },
      impact: { payroll: "direct_deposit_prenote", benefits: "none", compliance: "none" }
    }
  ],
  [
    employees.third,
    "tax_withholding",
    "Update federal withholding",
    "Morgan updated W-4 selections after a household change and needs payroll tax review.",
    "submitted",
    Date.current + 1.day,
    2.days.ago,
    {
      payload: {
        filing_status: "married_filing_jointly",
        extra_withholding_cents: 12_500,
        dependents_claimed: 1
      },
      impact: { payroll: "tax_withholding_update", benefits: "none", compliance: "w4_document" }
    }
  ],
  [
    employees.fourth,
    "work_location",
    "Move tax work location",
    "Riley moved to the Denver roastery and needs payroll tax and benefit eligibility review.",
    "submitted",
    Date.current + 7.days,
    3.days.ago,
    {
      payload: {
        work_location_id: locations.fetch("Denver Roastery").id,
        reason: "employee_relocation"
      },
      impact: { payroll: "state_tax_profile", benefits: "eligibility_review", compliance: "work_location_update" }
    }
  ],
  [
    employees.first,
    "emergency_contact",
    "Refresh emergency contact",
    "Avery added a new emergency contact from employee self-service.",
    "applied",
    Date.current,
    5.days.ago,
    {
      payload: {
        name: "Jamie Kim",
        relationship: "spouse",
        phone: "555-0134"
      },
      impact: { payroll: "none", benefits: "none", compliance: "profile_record" }
    }
  ],
  [
    employees.last,
    "profile_update",
    "Preferred name update",
    "Taylor requested a preferred name update that was rejected because the value matched the current profile.",
    "rejected",
    Date.current,
    7.days.ago,
    {
      payload: {
        preferred_name: "Taylor"
      },
      impact: { payroll: "none", benefits: "none", compliance: "none" },
      rejected_reason: "No profile change was required"
    }
  ]
].each do |employee, request_type, title, summary, status, effective_on, submitted_at, metadata|
  request = employee.employee_change_requests.find_or_initialize_by(request_type:, title:)
  request.assign_attributes(
    summary:,
    status:,
    effective_on:,
    submitted_at:,
    reviewed_at: status.in?([ "applied", "rejected", "sync_queued" ]) ? submitted_at + 4.hours : nil,
    reviewed_by: status.in?([ "applied", "rejected", "sync_queued" ]) ? "seed_data" : nil,
    applied_at: status.in?([ "applied", "sync_queued" ]) ? submitted_at + 4.hours : nil,
    rejected_at: status == "rejected" ? submitted_at + 4.hours : nil,
    metadata: metadata.deep_stringify_keys.merge("source" => "seeded_employee_self_service")
  )
  request.save!
end

current_performance_cycle = employer.performance_cycles.find_or_initialize_by(name: "#{Date.current.year} Midyear Performance Review")
current_performance_cycle.assign_attributes(
  status: "active",
  review_type: "quarterly",
  period_start_on: Date.current.beginning_of_year,
  period_end_on: Date.current.beginning_of_year + 6.months - 1.day,
  due_on: Date.current + 14.days,
  launched_at: 5.days.ago,
  metadata: { source: "seeded_performance_program", calibration_owner: "people_ops" }
)
current_performance_cycle.save!

next_performance_cycle = employer.performance_cycles.find_or_initialize_by(name: "#{Date.current.year} Year-End Performance Review")
next_performance_cycle.assign_attributes(
  status: "draft",
  review_type: "annual",
  period_start_on: Date.current.beginning_of_year,
  period_end_on: Date.current.end_of_year,
  due_on: Date.current.end_of_year + 14.days,
  metadata: { source: "seeded_performance_program", calibration_owner: "people_ops" }
)
next_performance_cycle.save!

[
  [ employees.first, employees.third, "complete", 5, Date.current - 2.days, "Built stable operating cadence across payroll, benefits, and compliance.", "Delegate more recurring analysis to functional leads." ],
  [ employees.second, employees.first, "manager_review", 4, Date.current + 6.days, "Strong retail team leadership during open enrollment intake.", "Needs tighter documentation around store manager handoffs." ],
  [ employees.third, employees.first, "self_review", nil, Date.current + 3.days, "Partnered well with remote employees on benefits changes.", "Self-review is still pending final employee submission." ],
  [ employees.fourth, employees.third, "calibration", 3, Date.current + 2.days, "Improved payroll funding controls and variance review.", "Needs clearer cross-training coverage for tax calendar work." ],
  [ employees[4], employees.first, "overdue", nil, Date.current - 2.days, "Strong Denver operations ownership.", "Manager review is overdue and needs follow-up." ],
  [ employees.last, employees.second, "manager_review", 4, Date.current + 8.days, "Consistent cafe execution and customer quality.", "Ready to expand into shift lead responsibilities." ]
].each do |employee, reviewer, status, rating, due_on, strengths, growth_areas|
  review = current_performance_cycle.performance_reviews.find_or_initialize_by(employee:)
  review.assign_attributes(
    reviewer:,
    status:,
    rating:,
    due_on:,
    self_submitted_at: status.in?([ "manager_review", "calibration", "complete" ]) ? 3.days.ago : nil,
    manager_submitted_at: status.in?([ "calibration", "complete" ]) ? 2.days.ago : nil,
    calibrated_at: status == "complete" ? 1.day.ago : nil,
    completed_at: status == "complete" ? 1.day.ago : nil,
    strengths:,
    growth_areas:,
    metadata: { source: "seeded_performance_review", review_channel: "manager_portal" }
  )
  review.save!
end

[
  [ employees.first, current_performance_cycle, "Reduce payroll exception rate", "Bring payroll exceptions under 1% for the next two biweekly runs.", "on_track", 72, Date.current + 21.days, "manager", "Exception rate below 1%" ],
  [ employees.second, current_performance_cycle, "Staff retail leadership bench", "Identify and train two shift leads before the year-end review cycle.", "at_risk", 38, Date.current + 30.days, "manager", "2 shift leads trained" ],
  [ employees.third, current_performance_cycle, "Complete benefits education series", "Publish employee-facing Vitable plan education and enrollment reminders.", "complete", 100, Date.current - 3.days, "employee", "Education series completed" ],
  [ employees.fourth, current_performance_cycle, "Document payroll funding backups", "Create a repeatable backup process for funding reviews and prenote exceptions.", "on_track", 64, Date.current + 18.days, "employee", "Backup runbook published" ],
  [ employees[4], current_performance_cycle, "Rebuild Denver roastery coverage", "Stabilize staffing and manager coverage ahead of final pay season.", "paused", 45, Date.current + 45.days, "manager", "Coverage plan approved" ]
].each do |employee, cycle, title, description, status, progress_percent, due_on, owner, metric|
  goal = employee.employee_goals.find_or_initialize_by(title:)
  goal.assign_attributes(
    performance_cycle: cycle,
    description:,
    status:,
    progress_percent:,
    due_on:,
    owner:,
    metric:,
    completed_at: status == "complete" ? 2.days.ago : nil,
    metadata: { source: "seeded_performance_goal" }
  )
  goal.save!
end

annual_training = employer.training_programs.find_or_initialize_by(title: "Annual compliance essentials")
annual_training.assign_attributes(
  category: "compliance",
  description: "Required handbook, harassment prevention, workplace safety, and payroll policy attestations.",
  audience: "all_employees",
  cadence: "annual",
  status: "active",
  launch_on: Date.current - 10.days,
  due_on: Date.current + 11.days,
  launched_at: 10.days.ago,
  metadata: { source: "seeded_training_program", owner: "people_ops" }
)
annual_training.save!

benefits_training = employer.training_programs.find_or_initialize_by(title: "Benefits policy attestation")
benefits_training.assign_attributes(
  category: "benefits",
  description: "Employee attestation for plan eligibility, dependent documentation, and payroll deduction changes.",
  audience: "benefits_eligible",
  cadence: "annual",
  status: "draft",
  launch_on: Date.current + 5.days,
  due_on: Date.current + 28.days,
  metadata: { source: "seeded_training_program", owner: "benefits_ops" }
)
benefits_training.save!

[
  [ employees.first, "complete", Date.current + 11.days, 5.days.ago, 98, "TRN-#{annual_training.id}-#{employees.first.id}-seed" ],
  [ employees.second, "in_progress", Date.current + 11.days, nil, nil, nil ],
  [ employees.third, "complete", Date.current + 11.days, 4.days.ago, 94, nil ],
  [ employees.fourth, "assigned", Date.current + 11.days, nil, nil, nil ],
  [ employees[4], "overdue", Date.current - 2.days, nil, nil, nil ],
  [ employees.last, "complete", Date.current + 11.days, 2.days.ago, 100, "TRN-#{annual_training.id}-#{employees.last.id}-seed" ]
].each do |employee, status, due_on, completed_at, score, certificate_id|
  assignment = annual_training.training_assignments.find_or_initialize_by(employee:)
  assignment.assign_attributes(
    status:,
    due_on:,
    started_at: status.in?([ "in_progress", "complete", "overdue" ]) ? 7.days.ago : nil,
    completed_at:,
    score:,
    certificate_id:,
    metadata: { source: "seeded_training_assignment", delivery_channel: "employee_portal" }
  )
  assignment.save!
end

annual_training.refresh_counts!
benefits_training.refresh_counts!

plans = [
  [ "Vitable Direct Primary Care", "direct_primary_care", "Vitable", 9_900, 3_900, 6_000, "published", "empl_atlas_dpc" ],
  [ "Minimum Essential Coverage", "minimum_essential_coverage", "Vitable", 14_900, 5_900, 9_000, "published", "empl_atlas_mec" ],
  [ "Dental + Vision", "dental_vision", "Vitable", 7_500, 2_500, 5_000, "published", "empl_atlas_dental_vision" ],
  [ "ICHRA Marketplace", "ichra", "Vitable", 28_500, 8_500, 20_000, "draft", nil ]
].to_h do |name, category, carrier, monthly_premium_cents, employee_contribution_cents, employer_contribution_cents, review_status, vitable_id|
  plan = employer.benefit_plans.find_or_initialize_by(name:)
  plan.assign_attributes(
    category:,
    carrier:,
    status: "available",
    monthly_premium_cents:,
    employee_contribution_cents:,
    employer_contribution_cents:,
    contribution_strategy: "fixed_employer_contribution",
    eligibility_rule: category == "ichra" ? "benefits_eligible_remote" : "active_full_time",
    plan_year: Date.current.year + 1,
    effective_on: Date.current.next_year.beginning_of_year,
    expires_on: Date.current.next_year.end_of_year,
    review_status:,
    published_at: review_status == "published" ? 1.week.ago : nil,
    vitable_id:,
    metadata: { source: "seeded_plan_catalog", catalog_owner: "benefits_ops" }
  )
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

[
  [ employees.first, "Jamie", "Kim", "spouse", "1989-03-04", "enrolled", "eligible" ],
  [ employees.first, "Parker", "Kim", "child", "2016-07-12", "enrolled", "eligible" ],
  [ employees.second, "Rowan", "Lee", "domestic_partner", "1991-11-20", "pending", "needs_review" ],
  [ employees.fourth, "Quinn", "Chen", "child", "2020-02-15", "enrolled", "needs_review" ],
  [ employees.last, "Sky", "Brooks", "child", "2019-05-01", "enrolled", "eligible" ]
].each do |employee, first_name, last_name, relationship, date_of_birth, enrollment_status, eligibility_status|
  dependent = employee.dependents.find_or_initialize_by(first_name:, last_name:, relationship:)
  dependent.assign_attributes(
    date_of_birth:,
    enrollment_status:,
    eligibility_status:,
    metadata: { source: "seed", verification_channel: "embedded_benefits" }
  )
  dependent.save!
end

open_enrollment_campaign = employer.open_enrollment_campaigns.find_or_initialize_by(plan_year: Date.current.year + 1)
open_enrollment_campaign.assign_attributes(
  name: "#{Date.current.year + 1} Open Enrollment",
  starts_on: Date.current.next_month.beginning_of_month,
  ends_on: Date.current.next_month.beginning_of_month + 21.days,
  status: "active",
  launched_at: 2.days.ago,
  reminders_sent_at: 1.day.ago,
  metadata: { source: "seeded_open_enrollment", channel: "employee_portal" }
)
open_enrollment_campaign.save!

[
  [ employees.first, "completed", 3.days.ago, 2.days.ago, nil ],
  [ employees.second, "sent", 2.days.ago, nil, nil ],
  [ employees.third, "opened", 2.days.ago, 1.day.ago, nil ],
  [ employees.fourth, "reminded", 2.days.ago, 1.day.ago, 1.day.ago ],
  [ employees[4], "blocked", 2.days.ago, nil, 1.day.ago ],
  [ employees.last, "waived", 3.days.ago, 2.days.ago, nil ]
].each do |employee, status, sent_at, opened_at, last_reminded_at|
  invitation = open_enrollment_campaign.open_enrollment_invitations.find_or_initialize_by(employee:)
  invitation.assign_attributes(
    status:,
    due_on: open_enrollment_campaign.ends_on,
    sent_at:,
    opened_at:,
    completed_at: status.in?([ "completed", "waived" ]) ? 1.day.ago : nil,
    last_reminded_at:,
    metadata: { source: "seeded_open_enrollment", reminder_count: last_reminded_at.present? ? 1 : 0 }
  )
  invitation.save!
end

[
  [
    employees.second,
    "department_transfer",
    Date.current + 14.days,
    "Jordan Lee is moving from Retail into People operations for open enrollment support.",
    "draft",
    {
      changes: { department: { from: "Retail", to: "People" } },
      payroll_impact: "tax_profile_review",
      benefits_impact: "none",
      compliance_impact: "manager_update"
    }
  ],
  [
    employees[4],
    "termination",
    Date.current + 21.days,
    "Sam Rivera has a scheduled separation requiring final pay and benefits offboarding.",
    "approved",
    {
      changes: { employment_status: { from: "active", to: "terminated" } },
      payroll_impact: "final_pay",
      benefits_impact: "end_coverage",
      compliance_impact: "cobra_review"
    }
  ],
  [
    employees.third,
    "compensation_change",
    Date.current + 30.days,
    "Morgan Patel compensation adjustment approved for the next payroll period.",
    "approved",
    {
      changes: { compensation_cents: { from: 92_000_00, to: 98_500_00 } },
      payroll_impact: "pay_rate_update",
      benefits_impact: "none",
      compliance_impact: "none"
    }
  ],
  [
    employees.last,
    "location_change",
    Date.current - 7.days,
    "Taylor Brooks moved into the Denver roastery location and is queued for HRIS sync.",
    "sync_queued",
    {
      changes: { work_location: { from: "Remote US", to: "Denver Roastery" } },
      payroll_impact: "tax_profile_review",
      benefits_impact: "eligibility_review",
      compliance_impact: "state_notice"
    }
  ]
].each do |employee, event_type, effective_on, summary, status, metadata|
  event = employee.employee_lifecycle_events.find_or_initialize_by(event_type:, summary:)
  event.assign_attributes(
    effective_on:,
    status:,
    reviewed_at: status == "draft" ? nil : 1.day.ago,
    source: "ops_console",
    metadata: metadata.merge(source: "seed")
  )
  event.save!
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
    [ "Form I-9", "identity", index == 4 ? "requested" : "complete", nil, index == 4 ? 4.days.ago : 30.days.ago, index == 4 ? nil : 26.days.ago, "employee_portal" ],
    [ "W-4", "tax", "complete", nil, 30.days.ago, 25.days.ago, "employee_portal" ],
    [ "Direct deposit authorization", "payroll", index == 2 ? "requested" : "complete", nil, index == 2 ? 2.days.ago : 18.days.ago, index == 2 ? nil : 17.days.ago, "payroll_console" ],
    [ "Benefits disclosure", "benefits", index == 1 ? "pending" : "complete", index == 3 ? Date.current + 25.days : Date.current + 180.days, index == 1 ? 5.days.ago : 20.days.ago, index == 1 ? nil : 19.days.ago, "vitable_embed" ],
    [ "Handbook acknowledgment", "policy", index == 3 ? "requested" : "complete", Date.current.end_of_year, index == 3 ? 1.day.ago : 14.days.ago, index == 3 ? nil : 13.days.ago, "employee_portal" ]
  ].each do |title, document_type, status, expires_on, requested_at, verified_at, source|
    document = employee.employee_documents.find_or_initialize_by(title:)
    document.assign_attributes(
      document_type:,
      status:,
      issued_on: status == "complete" ? Date.current - 20.days : nil,
      expires_on:,
      requested_at:,
      verified_at:,
      source:,
      metadata: {
        source: "seeded_document_vault",
        retention_policy: document_type == "identity" ? "i9_retention" : "employee_record",
        vitable_surface: document_type == "benefits"
      }
    )
    document.save!
  end
end

employer.dependents.includes(employee: [ :employee_documents ]).each_with_index do |dependent, index|
  document = dependent.employee.employee_documents.find { |item| item.document_type == "benefits" }
  verification = dependent.dependent_verifications.find_or_initialize_by(
    verification_type: dependent.relationship.in?([ "child", "step_child" ]) ? "birth_certificate" : "relationship_proof"
  )
  status = case index
  when 0, 1 then "approved"
  when 2 then "needs_review"
  when 3 then "rejected"
  else "requested"
  end
  verification.assign_attributes(
    employee_document: status == "requested" ? nil : document,
    status:,
    requested_on: Date.current - 10.days,
    due_on: Date.current + (index + 4).days,
    reviewed_at: status.in?([ "approved", "rejected" ]) ? 2.days.ago : nil,
    reviewed_by: status.in?([ "approved", "rejected" ]) ? "seed_data" : nil,
    issue_code: status == "rejected" ? "document_mismatch" : nil,
    note: status == "rejected" ? "Document relationship did not match the dependent profile." : nil,
    metadata: { source: "seeded_dependent_verification", channel: "employee_portal" }
  )
  verification.save!
  dependent.update!(enrollment_status: "enrolled", eligibility_status: "eligible") if status == "approved"
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

[
  [ employees.first, pto, "monthly_accrual", Date.current.beginning_of_month, Date.current.end_of_month, 13.33, "approved", "system", 2.days.ago ],
  [ employees.second, pto, "monthly_accrual", Date.current.beginning_of_month, Date.current.end_of_month, 13.33, "pending", "system", nil ],
  [ employees.third, pto, "monthly_accrual", Date.current.beginning_of_month, Date.current.end_of_month, 13.33, "approved", "system", 1.day.ago ],
  [ employees.fourth, sick, "monthly_accrual", Date.current.beginning_of_month, Date.current.end_of_month, 4.67, "approved", "system", 1.day.ago ],
  [ employees.last, pto, "carryover", Date.current.beginning_of_year, Date.current.beginning_of_year, 24, "approved", "import", 3.days.ago ]
].each do |employee, policy, accrual_type, period_start_on, period_end_on, hours, status, source, approved_at|
  accrual = employee.time_off_accruals.find_or_initialize_by(time_off_policy: policy, period_start_on:, accrual_type:)
  accrual.assign_attributes(
    hours:,
    period_end_on:,
    effective_on: period_end_on,
    source:,
    status:,
    approved_at:,
    metadata: { source: "seeded_pto_ledger", generated_by: "seed_data" }
  )
  accrual.save!
end

[
  [ employees.second, departments.fetch("RET"), locations.fetch("Philadelphia HQ"), "Retail floor lead", "published", 3, 8, 16, 30, 3_850, "Morning floor coverage" ],
  [ employees.last, departments.fetch("RET"), locations.fetch("Denver Roastery"), "Cafe associate", "published", 4, 7, 15, 30, 2_650, "Cafe open and service" ],
  [ employees.first, departments.fetch("OPS"), locations.fetch("Philadelphia HQ"), "Operations close", "draft", 5, 12, 20, 30, 6_350, "Close payroll exception queue" ],
  [ nil, departments.fetch("RET"), locations.fetch("Denver Roastery"), "Cafe associate", "draft", 6, 10, 18, 30, 2_650, "Open coverage gap for Denver" ],
  [ employees[4], departments.fetch("OPS"), locations.fetch("Denver Roastery"), "Roastery manager", "missed", 1, 6, 14, 30, 5_000, "Missed shift needs manager review" ],
  [ employees.fourth, departments.fetch("FIN"), locations.fetch("Remote US"), "Payroll operations", "completed", -1, 9, 17, 30, 4_700, "Completed payroll prep coverage" ]
].each do |employee, department, location, role, status, day_offset, start_hour, end_hour, break_minutes, hourly_rate_cents, notes|
  starts_at = (Date.current + day_offset.days).in_time_zone.change(hour: start_hour, min: 0)
  shift = employer.work_shifts.find_or_initialize_by(role:, starts_at:)
  shift.assign_attributes(
    employee:,
    department:,
    work_location: location,
    status:,
    ends_at: (Date.current + day_offset.days).in_time_zone.change(hour: end_hour, min: 0),
    break_minutes:,
    hourly_rate_cents:,
    notes:,
    published_at: status.in?([ "published", "completed", "missed" ]) ? 2.days.ago : nil,
    metadata: { source: "seeded_schedule", manager: "store_ops" }
  )
  shift.save!
end

retail_shift = employer.work_shifts.find_by(role: "Retail floor lead")
if retail_shift
  swap = retail_shift.shift_swap_requests.find_or_initialize_by(requester: employees.second)
  swap.assign_attributes(
    target_employee: employees.last,
    status: "submitted",
    reason: "Jordan needs coverage for a benefits enrollment appointment.",
    submitted_at: 10.hours.ago,
    metadata: { source: "seeded_shift_swap", employee_portal: true }
  )
  swap.save!
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

[
  [
    employees.first,
    current_run,
    "merit_increase",
    "submitted",
    "Annual merit adjustment for operations leadership scope.",
    employees.first.compensation_cents,
    employees.first.compensation_cents + 6_000_00,
    Date.current.next_month.beginning_of_month,
    "people_ops",
    2.days.ago,
    nil,
    nil,
    nil
  ],
  [
    employees.second,
    current_run,
    "promotion",
    "approved",
    "Retail lead promotion into multi-site customer experience management.",
    employees.second.compensation_cents,
    employees.second.compensation_cents + 8_500_00,
    current_run.pay_date,
    "people_ops",
    5.days.ago,
    "finance_admin",
    1.day.ago,
    nil
  ],
  [
    employees.third,
    current_run,
    "one_time_bonus",
    "approved",
    "Open enrollment implementation bonus pending payroll packaging.",
    employees.third.compensation_cents,
    employees.third.compensation_cents,
    current_run.pay_date,
    "people_ops",
    3.days.ago,
    "finance_admin",
    10.hours.ago,
    1_500_00
  ],
  [
    employees[4],
    current_run,
    "market_adjustment",
    "rejected",
    "Market adjustment paused until Denver roastery role leveling is complete.",
    employees[4].compensation_cents,
    employees[4].compensation_cents + 4_000_00,
    Date.current.next_month.beginning_of_month,
    "people_ops",
    6.days.ago,
    nil,
    nil,
    nil
  ]
].each do |employee, run, change_type, status, reason, current_cents, proposed_cents, effective_on, submitted_by, submitted_at, approved_by, approved_at, override_delta_cents|
  change = employer.compensation_changes.find_or_initialize_by(employee:, change_type:, reason:)
  delta_cents = override_delta_cents || proposed_cents - current_cents
  change.assign_attributes(
    payroll_run: run,
    status:,
    current_compensation_cents: current_cents,
    proposed_compensation_cents: proposed_cents,
    delta_cents:,
    effective_on:,
    submitted_by:,
    submitted_at:,
    approved_by:,
    approved_at:,
    rejected_by: status == "rejected" ? "finance_admin" : nil,
    rejected_at: status == "rejected" ? 1.day.ago : nil,
    rejection_reason: status == "rejected" ? "Role leveling needs to close before compensation approval." : nil,
    metadata: { source: "seeded_compensation_change", owner: "people_ops" }
  )
  change.save!
end

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
  [ employees.second, "Child support order", "child_support", "active", "fixed_amount", 325_00, nil, nil, nil, 10, false, "PA Domestic Relations", "DR-2026-1048", Date.current - 2.months, nil ],
  [ employees.third, "Transit commuter benefit", "benefit", "active", "fixed_amount", 120_00, nil, nil, nil, 40, true, "Musto Benefits", "TRN-COMMUTE", Date.current - 1.month, nil ],
  [ employees.fourth, "401k employee deferral", "retirement", "active", "percent_gross", 0, 500, 650_00, nil, 30, true, "Musto Retirement", "RET-DEFERRAL", Date.current - 3.months, nil ],
  [ employees[4], "Tax levy order", "tax_levy", "blocked", "court_order", 450_00, nil, 500_00, 4_800_00, 5, false, "Colorado Department of Revenue", "LEVY-8812", Date.current - 10.days, nil ],
  [ employees.last, "Equipment repayment", "equipment", "pending", "remaining_balance", 75_00, nil, 75_00, 525_00, 60, false, "Atlas Coffee Roasters", "EQ-ROASTER-22", Date.current + 5.days, nil ],
  [ employees.first, "Wellness advance repayment", "loan_repayment", "paused", "fixed_amount", 90_00, nil, nil, 360_00, 70, false, "Atlas Coffee Roasters", "ADV-2026-04", Date.current - 2.months, nil ]
].each do |employee, title, deduction_type, status, calculation_method, amount_cents, percent_basis_points, max_per_paycheck_cents, current_balance_cents, priority, pre_tax, agency_name, case_number, starts_on, ends_on|
  deduction = employer.employee_deductions.find_or_initialize_by(employee:, title:)
  deduction.assign_attributes(
    deduction_type:,
    status:,
    calculation_method:,
    amount_cents:,
    percent_basis_points:,
    max_per_paycheck_cents:,
    current_balance_cents:,
    priority:,
    pre_tax:,
    agency_name:,
    case_number:,
    starts_on:,
    ends_on:,
    approved_at: status == "active" ? 2.weeks.ago : nil,
    paused_at: status == "paused" ? 3.days.ago : nil,
    metadata: { source: "seeded_employee_deduction", payroll_review_owner: "payroll_ops" }
  )
  deduction.save!
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

[
  [ employees.first, "generated", nil, nil ],
  [ employees.fourth, "delivered", 1.day.ago, nil ],
  [ employees.last, "viewed", 2.days.ago, 1.day.ago ]
].each do |employee, status, delivered_at, viewed_at|
  gross_pay_cents = employee.compensation_cents / 24
  adjustment_cents = current_run.payroll_adjustments.where(employee:).sum(:amount_cents)
  deduction_cents = current_run.payroll_deductions.where(employee:).sum(:amount_cents)
  tax_cents = (gross_pay_cents * 0.18).round
  statement = current_run.pay_statements.find_or_initialize_by(employee:)
  statement.assign_attributes(
    statement_number: "PS-#{current_run.id}-#{employee.id}",
    period_start_on: current_run.period_start_on,
    period_end_on: current_run.period_end_on,
    pay_date: current_run.pay_date,
    gross_pay_cents:,
    adjustment_cents:,
    deduction_cents:,
    tax_cents:,
    net_pay_cents: gross_pay_cents + adjustment_cents - deduction_cents - tax_cents,
    status:,
    delivery_method: "employee_portal",
    delivered_at:,
    viewed_at:,
    metadata: { source: "seeded_pay_statement" }
  )
  statement.save!
end

benefit_invoice = employer.benefit_invoices.find_or_initialize_by(invoice_number: "VIT-#{employer.id}-#{Date.current.strftime("%Y%m")}")
benefit_invoice.assign_attributes(
  carrier: "Vitable",
  period_start_on: Date.current.beginning_of_month,
  period_end_on: Date.current.end_of_month,
  due_on: Date.current.end_of_month + 10.days,
  status: "needs_review",
  approved_at: nil,
  paid_at: nil,
  metadata: { source: "seeded_vitable_invoice", payment_method: "ach_debit" }
)
benefit_invoice.save!

employer.enrollments.accepted.includes(:employee, :benefit_plan, :payroll_deductions).each_with_index do |enrollment, index|
  plan_premium_cents = enrollment.benefit_plan.monthly_premium_cents
  invoice_amount_cents = index == 2 ? plan_premium_cents + 1_500 : plan_premium_cents
  deduction_cents = enrollment.payroll_deductions.where(payroll_run: current_run, status: "ready").sum(:amount_cents)
  employee_contribution_cents = [ deduction_cents, invoice_amount_cents ].min
  variance_cents = invoice_amount_cents - plan_premium_cents
  status = if variance_cents != 0
    "variance"
  elsif deduction_cents.zero?
    "missing_deduction"
  else
    "matched"
  end

  line = benefit_invoice.benefit_invoice_lines.find_or_initialize_by(employee: enrollment.employee, benefit_plan: enrollment.benefit_plan)
  line.assign_attributes(
    enrollment:,
    coverage_level: enrollment.coverage_level,
    amount_cents: invoice_amount_cents,
    expected_premium_cents: plan_premium_cents,
    expected_payroll_deduction_cents: deduction_cents,
    employee_contribution_cents:,
    employer_contribution_cents: invoice_amount_cents - employee_contribution_cents,
    variance_cents:,
    status:,
    metadata: { source: "seeded_vitable_invoice_line", remote_invoice_line_id: "vitable_line_#{enrollment.id}" }
  )
  line.save!
end

invoice_lines = benefit_invoice.benefit_invoice_lines.to_a
benefit_invoice.update!(
  total_premium_cents: invoice_lines.sum(&:amount_cents),
  employee_contribution_cents: invoice_lines.sum(&:employee_contribution_cents),
  employer_contribution_cents: invoice_lines.sum(&:employer_contribution_cents),
  variance_cents: invoice_lines.sum(&:variance_cents),
  status: invoice_lines.any?(&:blocked?) ? "needs_review" : "draft"
)

[
  [ employees.third, Date.current - 2.days, "Amtrak", "travel", "Open enrollment onsite travel", 184_00, "submitted", "uploaded", true, "employee_paid" ],
  [ employees.first, Date.current - 3.days, "Staples", "supplies", "Operations supplies for benefits launch", 86_00, "approved", "verified", true, "employee_paid" ],
  [ employees.second, Date.current - 1.day, "High Street Cafe", "meals", "Team lunch missing receipt", 145_00, "submitted", "missing", true, "employee_paid" ],
  [ employees.last, Date.current - 4.days, "City Gym", "wellness", "Out-of-policy wellness reimbursement request", 59_00, "submitted", "uploaded", false, "employee_paid" ]
].each do |employee, incurred_on, merchant, category, description, amount_cents, status, receipt_status, reimbursable, payment_method|
  expense = employee.employee_expenses.find_or_initialize_by(merchant:, incurred_on:, description:)
  expense.assign_attributes(
    category:,
    amount_cents:,
    status:,
    receipt_status:,
    reimbursable:,
    payment_method:,
    approved_at: status == "approved" ? 1.day.ago : nil,
    reimbursed_at: nil,
    metadata: { source: "seeded_expense_policy" }
  )
  expense.save!
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

PayrollCalendar::CalendarRepository.new(employer:).generate_checklist(requested_by: "seed_data")

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
