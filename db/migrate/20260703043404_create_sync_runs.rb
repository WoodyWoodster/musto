class CreateSyncRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :sync_runs do |t|
      t.references :integration_connection, null: false, foreign_key: true
      t.string :resource_type, null: false
      t.string :operation, null: false
      t.string :status, null: false, default: "running"
      t.datetime :started_at, null: false
      t.datetime :completed_at
      t.json :stats, null: false, default: {}
      t.text :error_message

      t.timestamps
    end

    add_index :sync_runs, [ :integration_connection_id, :resource_type, :created_at ], name: "idx_sync_runs_on_connection_resource_created"
    add_index :sync_runs, :status
  end
end
