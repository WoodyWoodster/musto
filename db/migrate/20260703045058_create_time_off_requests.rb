class CreateTimeOffRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :time_off_requests do |t|
      t.references :employee, null: false, foreign_key: true
      t.references :time_off_policy, null: false, foreign_key: true
      t.date :starts_on, null: false
      t.date :ends_on, null: false
      t.decimal :hours, precision: 8, scale: 2, null: false, default: 0
      t.string :status, null: false, default: "requested"
      t.text :reason
      t.datetime :reviewed_at
      t.json :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :time_off_requests, [ :employee_id, :starts_on ]
    add_index :time_off_requests, [ :status, :starts_on ]
  end
end
