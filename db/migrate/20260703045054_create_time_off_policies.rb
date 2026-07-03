class CreateTimeOffPolicies < ActiveRecord::Migration[8.1]
  def change
    create_table :time_off_policies do |t|
      t.references :employer, null: false, foreign_key: true
      t.string :name, null: false
      t.string :accrual_method, null: false, default: "annual_grant"
      t.decimal :annual_hours, precision: 8, scale: 2, null: false, default: 0
      t.decimal :carryover_hours, precision: 8, scale: 2, null: false, default: 0
      t.boolean :paid, null: false, default: true
      t.string :status, null: false, default: "active"
      t.json :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :time_off_policies, [ :employer_id, :name ], unique: true
    add_index :time_off_policies, [ :employer_id, :status ]
  end
end
