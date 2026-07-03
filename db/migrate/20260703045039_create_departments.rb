class CreateDepartments < ActiveRecord::Migration[8.1]
  def change
    create_table :departments do |t|
      t.references :employer, null: false, foreign_key: true
      t.string :name, null: false
      t.string :code, null: false
      t.integer :manager_id
      t.integer :budget_cents, null: false, default: 0
      t.json :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :departments, [ :employer_id, :code ], unique: true
    add_index :departments, :manager_id
    add_foreign_key :departments, :employees, column: :manager_id
  end
end
