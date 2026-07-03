class CreateTimeOffAccruals < ActiveRecord::Migration[8.1]
  def change
    create_table :time_off_accruals do |t|
      t.references :employee, null: false, foreign_key: true
      t.references :time_off_policy, null: false, foreign_key: true
      t.references :payroll_run, foreign_key: true
      t.string :accrual_type, null: false
      t.decimal :hours, precision: 8, scale: 2, default: 0, null: false
      t.date :period_start_on, null: false
      t.date :period_end_on, null: false
      t.date :effective_on, null: false
      t.string :source, default: "system", null: false
      t.string :status, default: "pending", null: false
      t.datetime :approved_at
      t.json :metadata, default: {}, null: false

      t.timestamps
    end

    add_index :time_off_accruals, [ :employee_id, :time_off_policy_id, :period_start_on, :accrual_type ], name: "idx_time_off_accruals_unique_period_type", unique: true
    add_index :time_off_accruals, [ :status, :effective_on ]
  end
end
