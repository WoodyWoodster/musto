class CreateEmployers < ActiveRecord::Migration[8.1]
  def change
    create_table :employers do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :vitable_id
      t.string :name, null: false
      t.string :legal_name
      t.string :ein
      t.string :status, null: false, default: "draft"
      t.datetime :onboarded_at
      t.json :settings, null: false, default: {}

      t.timestamps
    end

    add_index :employers, [ :organization_id, :vitable_id ], unique: true
    add_index :employers, [ :organization_id, :status ]
    add_index :employers, :ein
  end
end
