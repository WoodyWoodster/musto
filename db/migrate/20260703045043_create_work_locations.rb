class CreateWorkLocations < ActiveRecord::Migration[8.1]
  def change
    create_table :work_locations do |t|
      t.references :employer, null: false, foreign_key: true
      t.string :name, null: false
      t.string :address_line1
      t.string :city
      t.string :state
      t.string :postal_code
      t.string :country, null: false, default: "US"
      t.boolean :remote, null: false, default: false
      t.json :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :work_locations, [ :employer_id, :name ], unique: true
    add_index :work_locations, [ :employer_id, :state ]
  end
end
