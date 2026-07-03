class IntegrationConnection < ApplicationRecord
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
end
