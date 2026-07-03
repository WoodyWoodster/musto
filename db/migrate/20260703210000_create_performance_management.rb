class CreatePerformanceManagement < ActiveRecord::Migration[8.1]
  def change
    create_table :performance_cycles do |t|
      t.references :employer, null: false, foreign_key: true
      t.string :name, null: false
      t.string :status, null: false, default: "draft"
      t.string :review_type, null: false, default: "quarterly"
      t.date :period_start_on, null: false
      t.date :period_end_on, null: false
      t.date :due_on, null: false
      t.datetime :launched_at
      t.datetime :closed_at
      t.json :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :performance_cycles, [ :employer_id, :status ]
    add_index :performance_cycles, [ :employer_id, :period_start_on, :period_end_on ], name: "index_performance_cycles_on_employer_and_period"

    create_table :performance_reviews do |t|
      t.references :performance_cycle, null: false, foreign_key: true
      t.references :employee, null: false, foreign_key: true
      t.references :reviewer, foreign_key: { to_table: :employees }
      t.string :status, null: false, default: "draft"
      t.integer :rating
      t.text :strengths
      t.text :growth_areas
      t.date :due_on, null: false
      t.datetime :self_submitted_at
      t.datetime :manager_submitted_at
      t.datetime :calibrated_at
      t.datetime :completed_at
      t.json :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :performance_reviews, [ :performance_cycle_id, :employee_id ], unique: true, name: "index_performance_reviews_on_cycle_and_employee"
    add_index :performance_reviews, [ :status, :due_on ]

    create_table :employee_goals do |t|
      t.references :employee, null: false, foreign_key: true
      t.references :performance_cycle, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.string :status, null: false, default: "on_track"
      t.integer :progress_percent, null: false, default: 0
      t.date :due_on, null: false
      t.string :owner, null: false, default: "employee"
      t.string :metric
      t.datetime :completed_at
      t.json :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :employee_goals, [ :status, :due_on ]
  end
end
