class CreateEmployees < ActiveRecord::Migration[8.1]
  def change
    create_table :employees do |t|
      t.references :employer, null: false, foreign_key: true
      t.string :vitable_id
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :email, null: false
      t.date :date_of_birth
      t.string :employment_status, null: false, default: "active"
      t.json :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :employees, [ :employer_id, :email ], unique: true
    add_index :employees, [ :employer_id, :vitable_id ], unique: true
    add_index :employees, [ :employer_id, :employment_status ]
  end
end
