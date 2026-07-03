class AddManagerToEmployees < ActiveRecord::Migration[8.1]
  def change
    add_reference :employees, :manager, foreign_key: { to_table: :employees }
    add_index :employees, [ :employer_id, :manager_id ]
  end
end
