class CreateEmployeeLifecycleEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :employee_lifecycle_events do |t|
      t.references :employee, null: false, foreign_key: true
      t.string :event_type, null: false
      t.date :effective_on, null: false
      t.string :status, null: false, default: "draft"
      t.string :summary, null: false
      t.string :source, null: false, default: "ops_console"
      t.datetime :reviewed_at
      t.datetime :synced_at
      t.json :metadata, null: false, default: {}
      t.timestamps

      t.index [ :employee_id, :effective_on ]
      t.index [ :status, :effective_on ]
      t.index :event_type
    end
  end
end
