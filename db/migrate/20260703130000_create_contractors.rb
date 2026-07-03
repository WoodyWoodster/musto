class CreateContractors < ActiveRecord::Migration[8.1]
  def change
    create_table :contractors do |t|
      t.references :employer, null: false, foreign_key: true
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :email, null: false
      t.string :business_name
      t.string :contractor_type, null: false, default: "individual"
      t.string :status, null: false, default: "onboarding"
      t.string :tax_form_status, null: false, default: "missing"
      t.string :payment_method_status, null: false, default: "missing"
      t.date :start_on
      t.integer :hourly_rate_cents, null: false, default: 0
      t.json :metadata, null: false, default: {}
      t.timestamps

      t.index [ :employer_id, :email ], unique: true
      t.index [ :employer_id, :status ]
      t.index :tax_form_status
      t.index :payment_method_status
    end
  end
end
