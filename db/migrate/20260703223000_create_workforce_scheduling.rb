class CreateWorkforceScheduling < ActiveRecord::Migration[8.1]
  def change
    create_table :work_shifts do |t|
      t.references :employer, null: false, foreign_key: true
      t.references :employee, foreign_key: true
      t.references :department, foreign_key: true
      t.references :work_location, foreign_key: true
      t.string :role, null: false
      t.string :status, null: false, default: "draft"
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.integer :break_minutes, null: false, default: 0
      t.integer :hourly_rate_cents, null: false, default: 0
      t.text :notes
      t.datetime :published_at
      t.json :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :work_shifts, [ :employer_id, :status ]
    add_index :work_shifts, [ :employee_id, :starts_at ]
    add_index :work_shifts, [ :starts_at, :ends_at ]

    create_table :shift_swap_requests do |t|
      t.references :work_shift, null: false, foreign_key: true
      t.references :requester, null: false, foreign_key: { to_table: :employees }
      t.references :target_employee, foreign_key: { to_table: :employees }
      t.string :status, null: false, default: "submitted"
      t.text :reason
      t.datetime :submitted_at
      t.datetime :reviewed_at
      t.string :reviewed_by
      t.json :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :shift_swap_requests, [ :status, :submitted_at ]
    add_index :shift_swap_requests, [ :requester_id, :status ]
  end
end
