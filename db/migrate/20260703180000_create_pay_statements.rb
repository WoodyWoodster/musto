class CreatePayStatements < ActiveRecord::Migration[8.1]
  def change
    create_table :pay_statements do |t|
      t.references :payroll_run, null: false, foreign_key: true
      t.references :employee, null: false, foreign_key: true
      t.string :statement_number, null: false
      t.date :period_start_on, null: false
      t.date :period_end_on, null: false
      t.date :pay_date, null: false
      t.integer :gross_pay_cents, null: false, default: 0
      t.integer :adjustment_cents, null: false, default: 0
      t.integer :deduction_cents, null: false, default: 0
      t.integer :tax_cents, null: false, default: 0
      t.integer :net_pay_cents, null: false, default: 0
      t.string :status, null: false, default: "generated"
      t.string :delivery_method, null: false, default: "employee_portal"
      t.datetime :delivered_at
      t.datetime :viewed_at
      t.json :metadata, null: false, default: {}
      t.timestamps

      t.index [ :payroll_run_id, :employee_id ], unique: true
      t.index [ :payroll_run_id, :status ]
      t.index [ :employee_id, :pay_date ]
      t.index :statement_number, unique: true
      t.index :status
    end
  end
end
