class AddWorkforceFieldsToEmployees < ActiveRecord::Migration[8.1]
  def change
    add_reference :employees, :department, null: true, foreign_key: true
    add_reference :employees, :work_location, null: true, foreign_key: true
    add_column :employees, :title, :string
    add_column :employees, :start_on, :date
    add_column :employees, :compensation_cents, :integer, null: false, default: 0
    add_column :employees, :pay_type, :string, null: false, default: "salary"
    add_column :employees, :onboarding_status, :string, null: false, default: "complete"

    add_index :employees, [ :department_id, :employment_status ]
    add_index :employees, [ :work_location_id, :employment_status ]
    add_index :employees, :onboarding_status
  end
end
