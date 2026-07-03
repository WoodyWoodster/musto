class CreateYearEndTaxForms < ActiveRecord::Migration[8.1]
  def change
    create_table :year_end_tax_forms do |t|
      t.references :employer, null: false, foreign_key: true
      t.references :employee, foreign_key: true
      t.references :contractor, foreign_key: true
      t.integer :tax_year, null: false
      t.string :form_type, null: false
      t.string :recipient_name, null: false
      t.string :recipient_email, null: false
      t.string :tin_last4
      t.string :jurisdiction, default: "Federal", null: false
      t.integer :gross_wages_cents, default: 0, null: false
      t.integer :federal_withholding_cents, default: 0, null: false
      t.integer :state_withholding_cents, default: 0, null: false
      t.integer :benefit_reportable_cents, default: 0, null: false
      t.integer :contractor_payment_cents, default: 0, null: false
      t.string :status, default: "draft", null: false
      t.string :delivery_method, default: "employee_portal", null: false
      t.string :consent_status, default: "not_requested", null: false
      t.string :correction_status, default: "none", null: false
      t.date :due_on, null: false
      t.datetime :filed_at
      t.datetime :delivered_at
      t.datetime :accepted_at
      t.json :metadata, default: {}, null: false
      t.timestamps

      t.index [ :employer_id, :tax_year, :form_type ]
      t.index [ :employer_id, :status ]
      t.index [ :employee_id, :tax_year ], unique: true
      t.index [ :contractor_id, :tax_year ], unique: true
      t.index [ :status, :due_on ]
    end
  end
end
