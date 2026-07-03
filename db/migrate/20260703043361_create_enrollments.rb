class CreateEnrollments < ActiveRecord::Migration[8.1]
  def change
    create_table :enrollments do |t|
      t.references :employee, null: false, foreign_key: true
      t.references :benefit_plan, null: false, foreign_key: true
      t.string :vitable_id
      t.string :status, null: false, default: "pending"
      t.string :coverage_level, null: false, default: "employee"
      t.date :effective_on
      t.datetime :accepted_at
      t.json :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :enrollments, [ :employee_id, :benefit_plan_id ], unique: true
    add_index :enrollments, [ :employee_id, :vitable_id ], unique: true
    add_index :enrollments, :status
  end
end
