module Vitable
  module Configuration
    DEFAULT_ENVIRONMENT = "demo"
    PRODUCTION_ENVIRONMENT = "production"

    DEFAULT_API_KEY_REFERENCE = "VITABLE_CONNECT_API_KEY"
    DEFAULT_WEBHOOK_SECRET_REFERENCE = "VITABLE_WEBHOOK_SECRET"
    API_BASE_URL_ENV = "VITABLE_CONNECT_BASE_URL"
    ENVIRONMENT_ENV = "VITABLE_CONNECT_ENVIRONMENT"
    WIDGET_BASE_URL_ENV = "VITABLE_WIDGET_BASE_URL"
    WIDGET_TOKEN_BROKER_SECRET_REFERENCE = "VITABLE_WIDGET_TOKEN_BROKER_SECRET"

    DEMO_API_BASE_URL = "https://api.demo.vitablehealth.com"
    PRODUCTION_API_BASE_URL = "https://api.vitablehealth.com"
    DEFAULT_WIDGET_BASE_URL = "https://app.vitablehealth.com"

    DOCS_URL = "https://developer.vitablehealth.com/"
    RUBY_DOCS_URL = "https://developer.vitablehealth.com/api/ruby"
    WEBHOOKS_DOCS_URL = "https://developer.vitablehealth.com/webhooks/introduction"
    EMPLOYER_ONBOARDING_DOCS_URL = "https://developer.vitablehealth.com/embedded_benefits/guides/employer-onboarding/"
    BENEFITS_ADMINISTRATION_DOCS_URL = "https://developer.vitablehealth.com/embedded_benefits/guides/benefits-administration/"

    def self.default_environment
      ENV.fetch(ENVIRONMENT_ENV, DEFAULT_ENVIRONMENT).presence || DEFAULT_ENVIRONMENT
    end

    def self.configured_api_base_url(metadata = {})
      metadata.to_h.stringify_keys.fetch("api_base_url", nil).presence ||
        ENV.fetch(API_BASE_URL_ENV, nil).presence
    end

    def self.sdk_environment_for(environment)
      environment.presence || default_environment
    end

    def self.sdk_base_url_for(environment:, metadata: {})
      configured_api_base_url(metadata).presence || sdk_compatibility_base_url(environment)
    end

    def self.widget_base_url
      ENV.fetch(WIDGET_BASE_URL_ENV, DEFAULT_WIDGET_BASE_URL).presence || DEFAULT_WIDGET_BASE_URL
    end

    def self.docs_url(metadata = {})
      metadata.to_h.stringify_keys.fetch("docs", DOCS_URL)
    end

    def self.sdk_environment_supported?(environment)
      return false if environment.blank?
      return false unless defined?(VitableConnect::Client::ENVIRONMENTS)

      VitableConnect::Client::ENVIRONMENTS.key?(environment.to_s.to_sym)
    end

    def self.sdk_compatibility_base_url(environment)
      return DEMO_API_BASE_URL if environment.to_s == DEFAULT_ENVIRONMENT && !sdk_environment_supported?(environment)

      nil
    end

    private_class_method :sdk_compatibility_base_url
  end
end
