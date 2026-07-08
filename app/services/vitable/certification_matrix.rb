module Vitable
  module CertificationMatrix
    SUPPORTED_SCOPES = %w[full api].freeze

    CASES = [
      {
        key: "auth.issue_access_token",
        resource_type: "auth tokens",
        method: "POST",
        endpoint: EndpointCatalog::AUTH_ACCESS_TOKENS,
        operation: "auth.issue_access_token",
        sdk_resource_class: "VitableConnect::Resources::Auth",
        sdk_method: "issue_access_token",
        demo_supported: true
      },
      {
        key: "auth.issue_employer_access_token",
        resource_type: "auth tokens",
        method: "POST",
        endpoint: EndpointCatalog::AUTH_ACCESS_TOKENS,
        operation: "auth.issue_employer_access_token",
        sdk_resource_class: "VitableConnect::Resources::Auth",
        sdk_method: "issue_access_token",
        demo_supported: true
      },
      {
        key: "auth.issue_employee_access_token",
        resource_type: "auth tokens",
        method: "POST",
        endpoint: EndpointCatalog::AUTH_ACCESS_TOKENS,
        operation: "auth.issue_employee_access_token",
        sdk_resource_class: "VitableConnect::Resources::Auth",
        sdk_method: "issue_access_token",
        demo_supported: true
      },
      {
        key: "employer.list",
        resource_type: "employers",
        method: "GET",
        endpoint: EndpointCatalog::EMPLOYERS,
        operation: "employer.list",
        sdk_resource_class: "VitableConnect::Resources::Employers",
        sdk_method: "list",
        demo_supported: true
      },
      {
        key: "employer.create",
        resource_type: "employers",
        method: "POST",
        endpoint: EndpointCatalog::EMPLOYERS,
        operation: "employer.create",
        sdk_resource_class: "VitableConnect::Resources::Employers",
        sdk_method: "create",
        demo_supported: true
      },
      {
        key: "employer.retrieve",
        resource_type: "employers",
        method: "GET",
        endpoint: EndpointCatalog::EMPLOYER,
        operation: "employer.retrieve",
        sdk_resource_class: "VitableConnect::Resources::Employers",
        sdk_method: "retrieve",
        demo_supported: true
      },
      {
        key: "employer.update_settings",
        resource_type: "employer settings",
        method: "PUT",
        endpoint: EndpointCatalog::EMPLOYER_SETTINGS,
        operation: "employer.update_settings",
        sdk_resource_class: "VitableConnect::Resources::Employers",
        sdk_method: "update_settings",
        demo_supported: true
      },
      {
        key: "employer.census_sync",
        resource_type: "census sync",
        method: "POST",
        endpoint: EndpointCatalog::EMPLOYER_CENSUS_SYNC,
        operation: "employer.census_sync",
        sdk_resource_class: "VitableConnect::Resources::Employers",
        sdk_method: "submit_census_sync",
        demo_supported: true
      },
      {
        key: "employer.list_employees",
        resource_type: "remote roster",
        method: "GET",
        endpoint: EndpointCatalog::EMPLOYER_EMPLOYEES,
        operation: "employer.list_employees",
        sdk_resource_class: "VitableConnect::Resources::Employers",
        sdk_method: "list_employees",
        demo_supported: true
      },
      {
        key: "employee.retrieve",
        resource_type: "employees",
        method: "GET",
        endpoint: EndpointCatalog::EMPLOYEE,
        operation: "employee.retrieve",
        sdk_resource_class: "VitableConnect::Resources::Employees",
        sdk_method: "retrieve",
        demo_supported: true
      },
      {
        key: "employee.list_enrollments",
        resource_type: "employee enrollments",
        method: "GET",
        endpoint: EndpointCatalog::EMPLOYEE_ENROLLMENTS,
        operation: "employee.list_enrollments",
        sdk_resource_class: "VitableConnect::Resources::Employees",
        sdk_method: "list_enrollments",
        demo_supported: true
      },
      {
        key: "enrollment.retrieve",
        resource_type: "enrollments",
        method: "GET",
        endpoint: EndpointCatalog::ENROLLMENT,
        operation: "enrollment.retrieve",
        sdk_resource_class: "VitableConnect::Resources::Enrollments",
        sdk_method: "retrieve",
        demo_supported: true
      },
      {
        key: "plan.list",
        resource_type: "plans",
        method: "GET",
        endpoint: EndpointCatalog::PLANS,
        operation: "plan.list",
        sdk_resource_class: "VitableConnect::Resources::Plans",
        sdk_method: "list",
        demo_supported: true
      },
      {
        key: "group.list",
        resource_type: "groups",
        method: "GET",
        endpoint: EndpointCatalog::GROUPS,
        operation: "group.list",
        sdk_resource_class: "VitableConnect::Resources::Groups",
        sdk_method: "list",
        demo_supported: true
      },
      {
        key: "group.create",
        resource_type: "groups",
        method: "POST",
        endpoint: EndpointCatalog::GROUPS,
        operation: "group.create",
        sdk_resource_class: "VitableConnect::Resources::Groups",
        sdk_method: "create",
        demo_supported: true
      },
      {
        key: "group.retrieve",
        resource_type: "groups",
        method: "GET",
        endpoint: EndpointCatalog::GROUP,
        operation: "group.retrieve",
        sdk_resource_class: "VitableConnect::Resources::Groups",
        sdk_method: "retrieve",
        demo_supported: true
      },
      {
        key: "group.update",
        resource_type: "groups",
        method: "PATCH",
        endpoint: EndpointCatalog::GROUP,
        operation: "group.update",
        sdk_resource_class: "VitableConnect::Resources::Groups",
        sdk_method: "update",
        demo_supported: true
      },
      {
        key: "group.member_sync.submit",
        resource_type: "group member sync",
        method: "POST",
        endpoint: EndpointCatalog::GROUP_MEMBERS_SYNC,
        operation: "group.member_sync.submit",
        sdk_resource_class: "VitableConnect::Resources::Groups::Members::Sync",
        sdk_method: "submit",
        demo_supported: true
      },
      {
        key: "group.member_sync.retrieve",
        resource_type: "group member sync",
        method: "GET",
        endpoint: EndpointCatalog::GROUP_MEMBER_SYNC_REQUEST,
        operation: "group.member_sync.retrieve",
        sdk_resource_class: "VitableConnect::Resources::Groups::Members::Sync",
        sdk_method: "retrieve",
        demo_supported: true
      },
      {
        key: "webhook_event.list",
        resource_type: "webhook events",
        method: "GET",
        endpoint: EndpointCatalog::WEBHOOK_EVENTS,
        operation: "webhook_event.list",
        sdk_resource_class: "VitableConnect::Resources::WebhookEvents",
        sdk_method: "list",
        demo_supported: true
      },
      {
        key: "webhook_event.retrieve",
        resource_type: "webhook events",
        method: "GET",
        endpoint: EndpointCatalog::WEBHOOK_EVENT,
        operation: "webhook_event.retrieve",
        sdk_resource_class: "VitableConnect::Resources::WebhookEvents",
        sdk_method: "retrieve",
        demo_supported: true
      },
      {
        key: "webhook_event.list_deliveries",
        resource_type: "webhook event deliveries",
        method: "GET",
        endpoint: EndpointCatalog::WEBHOOK_EVENT_DELIVERIES,
        operation: "webhook_event.list_deliveries",
        sdk_resource_class: "VitableConnect::Resources::WebhookEvents",
        sdk_method: "list_deliveries",
        demo_supported: true
      },
      {
        key: "webhook.remote_delivery",
        resource_type: "remote webhook delivery",
        method: "WEBHOOK",
        endpoint: EndpointCatalog::LOCAL_WEBHOOK,
        operation: "webhook.remote_delivery",
        sdk_resource_class: nil,
        sdk_method: nil,
        demo_supported: true,
        transport: "vitable_delivery"
      },
      {
        key: "webhook.local_signed_fixtures",
        resource_type: "payload-only webhooks",
        method: "WEBHOOK",
        endpoint: EndpointCatalog::LOCAL_WEBHOOK,
        operation: "webhook.local_signed_fixtures",
        sdk_resource_class: nil,
        sdk_method: nil,
        demo_supported: true,
        transport: "local_signed_fixture"
      }
    ].freeze

    def self.cases(scope: "full")
      selected_cases = case normalized_scope(scope)
      when "full"
        CASES
      when "api"
        CASES.reject { |entry| webhook_case?(entry) }
      end

      selected_cases.map(&:dup)
    end

    def self.keys
      CASES.map { |entry| entry.fetch(:key) }
    end

    def self.find!(key)
      CASES.find { |entry| entry.fetch(:key) == key } || raise(KeyError, "unknown Vitable certification case #{key}")
    end

    def self.sdk_method_pairs
      CASES.filter_map do |entry|
        next if entry[:sdk_resource_class].blank? || entry[:sdk_method].blank?

        [ entry.fetch(:sdk_resource_class), entry.fetch(:sdk_method).to_s ]
      end.uniq
    end

    def self.normalized_scope(scope)
      normalized = scope.to_s.presence || "full"
      return normalized if SUPPORTED_SCOPES.include?(normalized)

      raise ArgumentError, "unknown Vitable certification scope #{scope.inspect}"
    end

    def self.webhook_case?(entry)
      entry.fetch(:key).start_with?("webhook")
    end
  end
end
