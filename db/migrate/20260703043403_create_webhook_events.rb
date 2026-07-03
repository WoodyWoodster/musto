class CreateWebhookEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :webhook_events do |t|
      t.references :integration_connection, null: true, foreign_key: true
      t.string :event_id, null: false
      t.string :organization_external_id, null: false
      t.string :event_name, null: false
      t.string :resource_type, null: false
      t.string :resource_id, null: false
      t.datetime :occurred_at, null: false
      t.datetime :processed_at
      t.string :status, null: false, default: "received"
      t.json :payload, null: false, default: {}
      t.text :error_message

      t.timestamps
    end

    add_index :webhook_events, :event_id, unique: true
    add_index :webhook_events, [ :organization_external_id, :created_at ]
    add_index :webhook_events, [ :resource_type, :resource_id ]
    add_index :webhook_events, :status
  end
end
