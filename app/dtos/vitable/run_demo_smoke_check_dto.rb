module Vitable
  RunDemoSmokeCheckDto = Data.define(:connection_id, :environment, :api_key_reference, :requested_by) do
    def self.from_env(env = ENV)
      new(
        connection_id: env.fetch("VITABLE_SMOKE_CONNECTION_ID", nil).presence,
        environment: env.fetch("VITABLE_CONNECT_ENVIRONMENT", "demo").presence || "demo",
        api_key_reference: env.fetch("VITABLE_CONNECT_API_KEY_REFERENCE", "VITABLE_CONNECT_API_KEY"),
        requested_by: env.fetch("VITABLE_SMOKE_REQUESTED_BY", "demo_smoke")
      )
    end
  end
end
