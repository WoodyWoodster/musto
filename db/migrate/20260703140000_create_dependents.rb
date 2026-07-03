class CreateDependents < ActiveRecord::Migration[8.1]
  def change
    create_table :dependents do |t|
      t.references :employee, null: false, foreign_key: true
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :relationship, null: false
      t.date :date_of_birth
      t.string :enrollment_status, null: false, default: "pending"
      t.string :eligibility_status, null: false, default: "needs_review"
      t.string :vitable_id
      t.json :metadata, null: false, default: {}
      t.timestamps

      t.index [ :employee_id, :relationship ]
      t.index [ :employee_id, :vitable_id ], unique: true
      t.index [ :eligibility_status, :enrollment_status ]
    end
  end
end
