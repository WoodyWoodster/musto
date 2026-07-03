class CreateWorkersCompPoliciesAndClaims < ActiveRecord::Migration[8.1]
  def change
    create_table :workers_comp_policies do |t|
      t.references :employer, null: false, foreign_key: true
      t.string :carrier, null: false
      t.string :policy_number, null: false
      t.string :status, default: "draft", null: false
      t.date :coverage_start_on, null: false
      t.date :coverage_end_on, null: false
      t.date :renewal_due_on, null: false
      t.integer :payroll_basis_cents, default: 0, null: false
      t.integer :manual_premium_cents, default: 0, null: false
      t.integer :deposit_premium_cents, default: 0, null: false
      t.integer :rate_basis_points, default: 250, null: false
      t.string :contact_name
      t.string :contact_email
      t.string :contact_phone
      t.string :certificate_url
      t.json :metadata, default: {}, null: false
      t.timestamps

      t.index [ :employer_id, :policy_number ], unique: true
      t.index [ :employer_id, :status ]
      t.index [ :status, :renewal_due_on ]
    end

    create_table :workers_comp_claims do |t|
      t.references :employer, null: false, foreign_key: true
      t.references :employee, null: false, foreign_key: true
      t.references :workers_comp_policy, null: false, foreign_key: true
      t.string :claim_number
      t.date :incident_on, null: false
      t.date :reported_on, null: false
      t.string :status, default: "reported", null: false
      t.string :severity, default: "medical_only", null: false
      t.string :injury_type
      t.string :body_part
      t.text :description, null: false
      t.integer :lost_time_days, default: 0, null: false
      t.integer :reserve_cents, default: 0, null: false
      t.integer :paid_cents, default: 0, null: false
      t.date :return_to_work_on
      t.datetime :closed_at
      t.json :metadata, default: {}, null: false
      t.timestamps

      t.index [ :employer_id, :status ]
      t.index [ :employee_id, :status ]
      t.index [ :workers_comp_policy_id, :status ]
      t.index [ :claim_number ], unique: true
      t.index [ :incident_on, :reported_on ]
    end
  end
end
