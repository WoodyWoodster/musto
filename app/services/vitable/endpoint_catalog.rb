module Vitable
  module EndpointCatalog
    AUTH_ACCESS_TOKENS = "/v1/auth/access-tokens"
    EMPLOYERS = "/v1/employers"
    EMPLOYER = "/v1/employers/:id"
    EMPLOYER_SETTINGS = "/v1/employers/:id/settings"
    EMPLOYER_SETTINGS_BY_EMPLOYER = "/v1/employers/:employer_id/settings"
    EMPLOYER_ELIGIBILITY_POLICIES = "/v1/employers/:id/benefit-eligibility-policies"
    EMPLOYER_ELIGIBILITY_POLICIES_BY_EMPLOYER = "/v1/employers/:employer_id/benefit-eligibility-policies"
    BENEFIT_ELIGIBILITY_POLICY = "/v1/benefit-eligibility-policies/:id"
    EMPLOYER_CENSUS_SYNC = "/v1/employers/:id/census-sync"
    EMPLOYER_CENSUS_SYNC_BY_EMPLOYER = "/v1/employers/:employer_id/census-sync"
    EMPLOYER_EMPLOYEES = "/v1/employers/:id/employees"
    EMPLOYEE = "/v1/employees/:id"
    EMPLOYEE_ENROLLMENTS = "/v1/employees/:id/enrollments"
    ENROLLMENT = "/v1/enrollments/:id"
    PLANS = "/v1/plans"
    GROUPS = "/v1/groups"
    GROUP = "/v1/groups/:id"
    GROUP_MEMBERS_SYNC = "/v1/groups/:id/members/sync"
    GROUP_MEMBERS_SYNC_BY_GROUP = "/v1/groups/:group_id/members/sync"
    GROUP_MEMBER_SYNC_REQUEST = "/v1/groups/:id/members/sync/:request_id"
    GROUP_MEMBER_SYNC_REQUEST_BY_GROUP = "/v1/groups/:group_id/members/sync/:request_id"
    WEBHOOK_EVENTS = "/v1/webhook-events"
    WEBHOOK_EVENT = "/v1/webhook-events/:id"
    WEBHOOK_EVENT_DELIVERIES = "/v1/webhook-events/:id/deliveries"
    WEBHOOK_EVENT_DELIVERIES_BY_EVENT = "/v1/webhook-events/:event_id/deliveries"
    LOCAL_WEBHOOK = "/api/v1/webhooks/vitable"

    PATHS = {
      auth_access_tokens: AUTH_ACCESS_TOKENS,
      employers: EMPLOYERS,
      employer: EMPLOYER,
      employer_settings: EMPLOYER_SETTINGS,
      employer_settings_by_employer: EMPLOYER_SETTINGS_BY_EMPLOYER,
      employer_eligibility_policies: EMPLOYER_ELIGIBILITY_POLICIES,
      employer_eligibility_policies_by_employer: EMPLOYER_ELIGIBILITY_POLICIES_BY_EMPLOYER,
      benefit_eligibility_policy: BENEFIT_ELIGIBILITY_POLICY,
      employer_census_sync: EMPLOYER_CENSUS_SYNC,
      employer_census_sync_by_employer: EMPLOYER_CENSUS_SYNC_BY_EMPLOYER,
      employer_employees: EMPLOYER_EMPLOYEES,
      employee: EMPLOYEE,
      employee_enrollments: EMPLOYEE_ENROLLMENTS,
      enrollment: ENROLLMENT,
      plans: PLANS,
      groups: GROUPS,
      group: GROUP,
      group_members_sync: GROUP_MEMBERS_SYNC,
      group_members_sync_by_group: GROUP_MEMBERS_SYNC_BY_GROUP,
      group_member_sync_request: GROUP_MEMBER_SYNC_REQUEST,
      group_member_sync_request_by_group: GROUP_MEMBER_SYNC_REQUEST_BY_GROUP,
      webhook_events: WEBHOOK_EVENTS,
      webhook_event: WEBHOOK_EVENT,
      webhook_event_deliveries: WEBHOOK_EVENT_DELIVERIES,
      webhook_event_deliveries_by_event: WEBHOOK_EVENT_DELIVERIES_BY_EVENT,
      local_webhook: LOCAL_WEBHOOK
    }.freeze

    COVERAGE_CATALOG = [
      {
        resource_type: "auth tokens",
        method: "POST",
        fetch_path: AUTH_ACCESS_TOKENS,
        operations: %w[auth.issue_access_token auth.issue_employee_access_token auth.issue_employer_access_token],
        sync_operations: %w[embedded_enrollment_token embedded_admin_token widget_token_broker demo_smoke_check]
      },
      {
        resource_type: "employers",
        method: "GET/POST",
        fetch_path: EMPLOYERS,
        operations: %w[employer.list employer.create employer.retrieve],
        sync_operations: %w[employer_create api_snapshot_refresh demo_smoke_check],
        resource_fetch_fragments: %w[/employers/],
        fetch_resource_types: %w[employer],
        snapshot_count_key: "remote_employer_count",
        event_resource_types: %w[employer]
      },
      {
        resource_type: "employer settings",
        method: "PUT",
        fetch_path: EMPLOYER_SETTINGS,
        operations: %w[employer.update_settings],
        sync_operations: %w[employer_settings_update]
      },
      {
        resource_type: "eligibility policy creation",
        method: "POST",
        fetch_path: EMPLOYER_ELIGIBILITY_POLICIES,
        operations: %w[employer.eligibility_policy.create],
        sync_operations: %w[employer_create employer_settings_update]
      },
      {
        resource_type: "eligibility policy retrieval",
        method: "GET",
        fetch_path: BENEFIT_ELIGIBILITY_POLICY,
        operations: %w[eligibility_policy.retrieve],
        sync_operations: %w[api_snapshot_refresh],
        resource_fetch_fragments: %w[/benefit-eligibility-policies/],
        fetch_resource_types: %w[eligibility_policy benefit_eligibility_policy]
      },
      {
        resource_type: "census sync",
        method: "POST",
        fetch_path: EMPLOYER_CENSUS_SYNC,
        operations: %w[employer.census_sync],
        sync_operations: %w[census_sync]
      },
      {
        resource_type: "remote roster",
        method: "GET",
        fetch_path: EMPLOYER_EMPLOYEES,
        operations: %w[employer.list_employees],
        sync_operations: %w[remote_roster_refresh demo_smoke_check],
        snapshot_count_key: "mapped_employee_count"
      },
      {
        resource_type: "employees",
        method: "GET",
        fetch_path: EMPLOYEE,
        operations: %w[employee.retrieve],
        resource_fetch_fragments: %w[/employees/],
        fetch_resource_types: %w[employee],
        snapshot_count_key: "retrieved_remote_employee_count",
        event_resource_types: %w[employee]
      },
      {
        resource_type: "employee enrollments",
        method: "GET",
        fetch_path: EMPLOYEE_ENROLLMENTS,
        operations: %w[employee.list_enrollments],
        sync_operations: %w[api_snapshot_refresh demo_smoke_check],
        snapshot_count_key: "remote_employee_enrollment_count"
      },
      {
        resource_type: "enrollments",
        method: "GET",
        fetch_path: ENROLLMENT,
        operations: %w[enrollment.retrieve],
        resource_fetch_fragments: %w[/enrollments/],
        fetch_resource_types: %w[enrollment],
        snapshot_count_key: "retrieved_remote_enrollment_count",
        event_resource_types: %w[enrollment]
      },
      {
        resource_type: "plans",
        method: "GET",
        fetch_path: PLANS,
        operations: %w[plan.list],
        sync_operations: %w[plan_mapping_refresh api_snapshot_refresh demo_smoke_check],
        snapshot_count_key: "remote_plan_count"
      },
      {
        resource_type: "groups",
        method: "GET/POST/PATCH",
        fetch_path: GROUPS,
        operations: %w[group.list group.retrieve group.create group.update],
        sync_operations: %w[care_group_upsert api_snapshot_refresh demo_smoke_check],
        fetch_resource_types: %w[group],
        snapshot_count_key: "remote_group_count",
        event_resource_types: %w[group]
      },
      {
        resource_type: "group member sync",
        method: "POST/GET",
        fetch_path: GROUP_MEMBERS_SYNC,
        operations: %w[group.member_sync.submit group.member_sync.retrieve],
        sync_operations: %w[care_member_sync_submit care_member_sync_refresh],
        snapshot_count_key: "remote_care_member_sync_count"
      },
      {
        resource_type: "webhook events",
        method: "GET",
        fetch_path: WEBHOOK_EVENTS,
        operations: %w[webhook_event.list webhook_event.retrieve],
        sync_operations: %w[webhook_replay webhook_delivery_refresh api_snapshot_refresh demo_smoke_check],
        fetch_resource_types: %w[webhook_event],
        snapshot_count_key: "remote_webhook_event_count"
      },
      {
        resource_type: "webhook event deliveries",
        method: "GET",
        fetch_path: WEBHOOK_EVENT_DELIVERIES,
        operations: %w[webhook_event.list_deliveries],
        sync_operations: %w[webhook_delivery_refresh api_snapshot_refresh],
        snapshot_count_key: "remote_webhook_delivery_count"
      },
      {
        resource_type: "payload-only webhooks",
        method: "WEBHOOK",
        fetch_path: LOCAL_WEBHOOK,
        operations: %w[webhook.payload_only],
        event_resource_types: %w[dependent payroll_deduction plan_year]
      }
    ].freeze

    def self.coverage_catalog
      COVERAGE_CATALOG
    end

    def self.path(key, **params)
      PATHS.fetch(key).dup.tap do |template|
        params.each { |name, value| template.gsub!(":#{name}", value.to_s) }
        unresolved = template.scan(/:\w+/)
        raise KeyError, "missing endpoint parameter #{unresolved.first} for #{key}" if unresolved.any?
      end
    end
  end
end
