class IntegrationConnection < ApplicationRecord
  DEMO_BASE_URL = "https://api.demo.vitablehealth.com"

  belongs_to :organization

  has_many :webhook_events, dependent: :nullify
  has_many :sync_runs, dependent: :destroy
  has_many :api_request_logs, dependent: :destroy

  validates :provider, :environment, :api_key_reference, :status, presence: true
  validates :provider, uniqueness: { scope: [ :organization_id, :environment ] }

  scope :vitable, -> { where(provider: "vitable") }

  def api_key
    ENV.fetch(api_key_reference, nil)
  end

  def credentials_present?
    api_key.present?
  end

  def webhook_secret
    ENV.fetch(webhook_secret_reference, nil) if webhook_secret_reference.present?
  end

  def webhook_secret_present?
    webhook_secret.present?
  end

  def effective_api_base_url
    configured_api_base_url.presence || (environment == "demo" ? DEMO_BASE_URL : nil)
  end

  private

  def configured_api_base_url
    metadata.to_h.stringify_keys.fetch("api_base_url", nil).presence ||
      ENV.fetch("VITABLE_CONNECT_BASE_URL", nil).presence
  end
end
