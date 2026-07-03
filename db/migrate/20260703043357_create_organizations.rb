class CreateOrganizations < ActiveRecord::Migration[8.1]
  def change
    create_table :organizations do |t|
      t.string :name, null: false
      t.string :external_id
      t.string :status, null: false, default: "active"
      t.json :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :organizations, :external_id, unique: true
    add_index :organizations, :status
  end
end
