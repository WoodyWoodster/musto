class CreatePayrollRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :payroll_runs do |t|
      t.references :employer, null: false, foreign_key: true
      t.date :period_start_on, null: false
      t.date :period_end_on, null: false
      t.date :pay_date, null: false
      t.string :status, null: false, default: "draft"
      t.integer :gross_pay_cents, null: false, default: 0
      t.json :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :payroll_runs, [ :employer_id, :pay_date ]
    add_index :payroll_runs, [ :employer_id, :status ]
  end
end
