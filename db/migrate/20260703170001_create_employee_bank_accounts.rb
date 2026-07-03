class CreateEmployeeBankAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :employee_bank_accounts do |t|
      t.references :employee, null: false, foreign_key: true
      t.string :nickname, null: false
      t.string :institution_name, null: false
      t.string :account_type, null: false, default: "checking"
      t.string :routing_number_last4, null: false
      t.string :account_last4, null: false
      t.string :allocation_type, null: false, default: "remainder"
      t.integer :allocation_value, null: false, default: 100
      t.string :status, null: false, default: "pending_verification"
      t.string :verification_method, null: false, default: "prenote"
      t.boolean :primary_account, null: false, default: true
      t.datetime :verified_at
      t.datetime :prenote_sent_at
      t.json :metadata, null: false, default: {}
      t.timestamps

      t.index [ :employee_id, :primary_account ]
      t.index [ :employee_id, :status ]
      t.index :status
    end
  end
end
