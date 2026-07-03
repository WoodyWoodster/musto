class CreateEmployeeChangeRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :employee_change_requests do |t|
      t.references :employee, null: false, foreign_key: true
      t.string :request_type, null: false
      t.string :title, null: false
      t.text :summary
      t.string :status, null: false, default: "submitted"
      t.date :effective_on, null: false
      t.datetime :submitted_at, null: false
      t.datetime :reviewed_at
      t.string :reviewed_by
      t.datetime :applied_at
      t.datetime :rejected_at
      t.json :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :employee_change_requests, [ :employee_id, :status ]
    add_index :employee_change_requests, [ :request_type, :status ]
    add_index :employee_change_requests, [ :status, :submitted_at ]
  end
end
