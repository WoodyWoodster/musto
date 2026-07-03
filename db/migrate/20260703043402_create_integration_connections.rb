class CreateIntegrationConnections < ActiveRecord::Migration[8.1]
  def change
    create_table :integration_connections do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :provider, null: false
      t.string :environment, null: false, default: "production"
      t.string :api_key_reference, null: false, default: "VITABLE_CONNECT_API_KEY"
      t.string :webhook_secret_reference
      t.string :status, null: false, default: "needs_credentials"
      t.datetime :last_synced_at
      t.json :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :integration_connections, [ :organization_id, :provider, :environment ], unique: true, name: "idx_integration_connections_unique_provider_environment"
    add_index :integration_connections, :status
  end
end
