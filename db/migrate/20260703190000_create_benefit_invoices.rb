class CreateBenefitInvoices < ActiveRecord::Migration[8.1]
  def change
    create_table :benefit_invoices do |t|
      t.references :employer, null: false, foreign_key: true
      t.string :invoice_number, null: false
      t.string :carrier, null: false
      t.date :period_start_on, null: false
      t.date :period_end_on, null: false
      t.date :due_on, null: false
      t.string :status, null: false, default: "draft"
      t.integer :total_premium_cents, null: false, default: 0
      t.integer :employee_contribution_cents, null: false, default: 0
      t.integer :employer_contribution_cents, null: false, default: 0
      t.integer :variance_cents, null: false, default: 0
      t.datetime :approved_at
      t.datetime :paid_at
      t.json :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :benefit_invoices, [ :employer_id, :invoice_number ], unique: true
    add_index :benefit_invoices, [ :status, :due_on ]
    add_index :benefit_invoices, [ :carrier, :period_start_on ]

    create_table :benefit_invoice_lines do |t|
      t.references :benefit_invoice, null: false, foreign_key: true
      t.references :employee, null: false, foreign_key: true
      t.references :benefit_plan, null: false, foreign_key: true
      t.references :enrollment, foreign_key: true
      t.string :coverage_level, null: false
      t.integer :amount_cents, null: false, default: 0
      t.integer :expected_premium_cents, null: false, default: 0
      t.integer :expected_payroll_deduction_cents, null: false, default: 0
      t.integer :employee_contribution_cents, null: false, default: 0
      t.integer :employer_contribution_cents, null: false, default: 0
      t.integer :variance_cents, null: false, default: 0
      t.string :status, null: false, default: "matched"
      t.json :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :benefit_invoice_lines, [ :benefit_invoice_id, :status ]
    add_index :benefit_invoice_lines, [ :employee_id, :benefit_plan_id ]
    add_index :benefit_invoice_lines, :variance_cents
  end
end
