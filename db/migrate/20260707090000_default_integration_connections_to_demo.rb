class DefaultIntegrationConnectionsToDemo < ActiveRecord::Migration[8.1]
  def change
    change_column_default :integration_connections, :environment, from: "production", to: "demo"
  end
end
