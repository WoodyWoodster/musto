class CreateBenefitPlans < ActiveRecord::Migration[8.1]
  def change
    create_table :benefit_plans do |t|
      t.references :employer, null: false, foreign_key: true
      t.string :vitable_id
      t.string :name, null: false
      t.string :category, null: false
      t.string :carrier
      t.string :status, null: false, default: "available"
      t.integer :monthly_premium_cents, null: false, default: 0
      t.json :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :benefit_plans, [ :employer_id, :vitable_id ], unique: true
    add_index :benefit_plans, [ :employer_id, :category ]
    add_index :benefit_plans, [ :employer_id, :status ]
  end
end
