class CreatePayrollDeductions < ActiveRecord::Migration[8.1]
  def change
    create_table :payroll_deductions do |t|
      t.references :payroll_run, null: false, foreign_key: true
      t.references :employee, null: false, foreign_key: true
      t.references :enrollment, null: true, foreign_key: true
      t.string :vitable_id
      t.integer :amount_cents, null: false, default: 0
      t.string :code, null: false
      t.string :status, null: false, default: "estimated"
      t.json :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :payroll_deductions, [ :payroll_run_id, :employee_id, :code ], name: "idx_payroll_deductions_on_run_employee_code"
    add_index :payroll_deductions, :vitable_id, unique: true
    add_index :payroll_deductions, :status
  end
end
