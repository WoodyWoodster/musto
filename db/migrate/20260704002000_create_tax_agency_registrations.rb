class CreateTaxAgencyRegistrations < ActiveRecord::Migration[8.1]
  def change
    create_table :tax_agency_registrations do |t|
      t.references :employer, null: false, foreign_key: true
      t.references :work_location, foreign_key: true
      t.string :agency_name, null: false
      t.string :jurisdiction, null: false
      t.string :registration_type, null: false
      t.string :account_number
      t.string :deposit_schedule, default: "registration_pending", null: false
      t.string :status, default: "draft", null: false
      t.string :risk_level, default: "medium", null: false
      t.date :due_on, null: false
      t.datetime :submitted_at
      t.datetime :confirmed_at
      t.string :confirmation_number
      t.date :next_deposit_due_on
      t.string :owner, default: "Payroll", null: false
      t.text :notes
      t.json :metadata, default: {}, null: false
      t.timestamps

      t.index [ :employer_id, :jurisdiction ]
      t.index [ :employer_id, :status ]
      t.index [ :status, :due_on ]
      t.index [ :agency_name, :registration_type ]
    end
  end
end
