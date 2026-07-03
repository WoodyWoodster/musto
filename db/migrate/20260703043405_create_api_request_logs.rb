class CreateApiRequestLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :api_request_logs do |t|
      t.references :integration_connection, null: false, foreign_key: true
      t.string :operation, null: false
      t.string :method, null: false
      t.string :path, null: false
      t.integer :status_code
      t.integer :duration_ms
      t.json :request_body, null: false, default: {}
      t.json :response_body, null: false, default: {}
      t.string :error_class
      t.text :error_message

      t.timestamps
    end

    add_index :api_request_logs, [ :integration_connection_id, :operation, :created_at ], name: "idx_api_request_logs_on_connection_operation_created"
    add_index :api_request_logs, :status_code
  end
end
