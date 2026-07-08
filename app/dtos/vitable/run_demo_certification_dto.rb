module Vitable
  RunDemoCertificationDto = Data.define(
    :connection_id,
    :environment,
    :api_key_reference,
    :webhook_secret_reference,
    :public_webhook_url,
    :requested_by,
    :artifact_dir,
    :webhook_wait_seconds
  ) do
    def self.from_env(env = ENV)
      new(
        connection_id: env.fetch("VITABLE_CERTIFICATION_CONNECTION_ID", nil).presence,
        environment: env.fetch(Vitable::Configuration::ENVIRONMENT_ENV, Vitable::Configuration::DEFAULT_ENVIRONMENT).presence || Vitable::Configuration::DEFAULT_ENVIRONMENT,
        api_key_reference: env.fetch("VITABLE_CONNECT_API_KEY_REFERENCE", Vitable::Configuration::DEFAULT_API_KEY_REFERENCE),
        webhook_secret_reference: env.fetch("VITABLE_WEBHOOK_SECRET_REFERENCE", Vitable::Configuration::DEFAULT_WEBHOOK_SECRET_REFERENCE),
        public_webhook_url: env.fetch("VITABLE_PUBLIC_WEBHOOK_URL", nil).presence,
        requested_by: env.fetch("VITABLE_CERTIFICATION_REQUESTED_BY", "demo_certification"),
        artifact_dir: env.fetch("VITABLE_CERTIFICATION_ARTIFACT_DIR", Rails.root.join("tmp/vitable/certifications").to_s),
        webhook_wait_seconds: env.fetch("VITABLE_CERTIFICATION_WEBHOOK_WAIT_SECONDS", "0").to_i
      )
    end
  end
end
