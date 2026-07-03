module Dashboard
  IntegrationHealthDto = Data.define(:active, :needs_credentials, :pending_webhooks)
end
