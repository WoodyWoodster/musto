class CreatePayrollAdjustments < ActiveRecord::Migration[8.1]
  def change
    create_table :payroll_adjustments do |t|
      t.references :payroll_run, null: false, foreign_key: true
      t.references :employee, null: false, foreign_key: true
      t.string :adjustment_type, null: false
      t.integer :amount_cents, null: false, default: 0
      t.string :description, null: false
      t.boolean :taxable, null: false, default: true
      t.json :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :payroll_adjustments, [ :payroll_run_id, :employee_id ]
    add_index :payroll_adjustments, :adjustment_type
  end
end
