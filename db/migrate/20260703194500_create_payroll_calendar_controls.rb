class CreatePayrollCalendarControls < ActiveRecord::Migration[8.1]
  def change
    create_table :payroll_schedules do |t|
      t.references :employer, null: false, foreign_key: true
      t.string :name, null: false
      t.string :cadence, null: false
      t.string :status, null: false, default: "active"
      t.date :period_anchor_on, null: false
      t.date :next_period_start_on, null: false
      t.date :next_period_end_on, null: false
      t.date :next_pay_date, null: false
      t.datetime :approval_deadline_at, null: false
      t.datetime :funding_deadline_at, null: false
      t.string :timezone, null: false, default: "America/Los_Angeles"
      t.json :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :payroll_schedules, [ :employer_id, :name ], unique: true
    add_index :payroll_schedules, [ :employer_id, :status, :next_pay_date ]

    create_table :payroll_approval_steps do |t|
      t.references :payroll_run, null: false, foreign_key: true
      t.references :payroll_schedule, foreign_key: true
      t.string :key, null: false
      t.string :title, null: false
      t.string :owner, null: false
      t.string :status, null: false, default: "open"
      t.string :severity, null: false, default: "medium"
      t.integer :position, null: false, default: 0
      t.datetime :due_at, null: false
      t.datetime :completed_at
      t.string :completed_by
      t.json :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :payroll_approval_steps, [ :payroll_run_id, :key ], unique: true
    add_index :payroll_approval_steps, [ :status, :due_at ]
    add_index :payroll_approval_steps, [ :position, :due_at ]
  end
end
