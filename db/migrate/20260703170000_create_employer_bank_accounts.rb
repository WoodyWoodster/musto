class CreateEmployerBankAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :employer_bank_accounts do |t|
      t.references :employer, null: false, foreign_key: true
      t.string :name, null: false
      t.string :institution_name, null: false
      t.string :account_type, null: false, default: "checking"
      t.string :routing_number_last4, null: false
      t.string :account_last4, null: false
      t.string :status, null: false, default: "pending_verification"
      t.string :verification_method, null: false, default: "microdeposit"
      t.boolean :primary_account, null: false, default: false
      t.datetime :verified_at
      t.json :metadata, null: false, default: {}
      t.timestamps

      t.index [ :employer_id, :primary_account ]
      t.index [ :employer_id, :status ]
      t.index :status
    end
  end
end
