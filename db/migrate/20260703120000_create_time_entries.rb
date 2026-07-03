class CreateTimeEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :time_entries do |t|
      t.references :employee, null: false, foreign_key: true
      t.date :work_date, null: false
      t.datetime :clock_in_at, null: false
      t.datetime :clock_out_at, null: false
      t.integer :break_minutes, default: 0, null: false
      t.string :source, default: "web", null: false
      t.string :status, default: "submitted", null: false
      t.text :notes
      t.datetime :approved_at
      t.datetime :reviewed_at
      t.json :metadata, default: {}, null: false

      t.timestamps
    end

    add_index :time_entries, [ :employee_id, :work_date ]
    add_index :time_entries, [ :status, :work_date ]
    add_index :time_entries, :source
  end
end
