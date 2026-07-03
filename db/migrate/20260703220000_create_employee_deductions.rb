class CreateEmployeeDeductions < ActiveRecord::Migration[8.1]
  def change
    create_table :employee_deductions do |t|
      t.references :employer, null: false, foreign_key: true
      t.references :employee, null: false, foreign_key: true
      t.string :title, null: false
      t.string :deduction_type, null: false, default: "other"
      t.string :status, null: false, default: "pending"
      t.string :calculation_method, null: false, default: "fixed_amount"
      t.integer :amount_cents, null: false, default: 0
      t.integer :percent_basis_points
      t.integer :max_per_paycheck_cents
      t.integer :current_balance_cents
      t.integer :priority, null: false, default: 50
      t.boolean :pre_tax, null: false, default: false
      t.string :agency_name
      t.string :case_number
      t.date :starts_on, null: false
      t.date :ends_on
      t.datetime :approved_at
      t.datetime :paused_at
      t.datetime :closed_at
      t.json :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :employee_deductions, [ :employer_id, :status ]
    add_index :employee_deductions, [ :employee_id, :status ]
    add_index :employee_deductions, [ :deduction_type, :priority ]
    add_index :employee_deductions, [ :case_number, :agency_name ]
  end
end
