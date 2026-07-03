class CreateEmployeeExpenses < ActiveRecord::Migration[8.1]
  def change
    create_table :employee_expenses do |t|
      t.references :employee, null: false, foreign_key: true
      t.date :incurred_on, null: false
      t.string :merchant, null: false
      t.string :category, null: false
      t.text :description
      t.integer :amount_cents, null: false, default: 0
      t.string :status, null: false, default: "submitted"
      t.string :receipt_status, null: false, default: "missing"
      t.string :payment_method, null: false, default: "employee_paid"
      t.boolean :reimbursable, null: false, default: true
      t.datetime :approved_at
      t.datetime :reimbursed_at
      t.json :metadata, null: false, default: {}
      t.timestamps

      t.index [ :employee_id, :incurred_on ]
      t.index [ :status, :incurred_on ]
      t.index :category
      t.index :receipt_status
    end
  end
end
