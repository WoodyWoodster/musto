class CreateDependentVerifications < ActiveRecord::Migration[8.1]
  def change
    create_table :dependent_verifications do |t|
      t.references :dependent, null: false, foreign_key: true
      t.references :employee_document, foreign_key: true
      t.string :verification_type, null: false
      t.string :status, default: "requested", null: false
      t.date :requested_on, null: false
      t.date :due_on, null: false
      t.datetime :reviewed_at
      t.string :reviewed_by
      t.string :issue_code
      t.text :note
      t.json :metadata, default: {}, null: false

      t.timestamps
    end

    add_index :dependent_verifications, [ :dependent_id, :verification_type ], unique: true
    add_index :dependent_verifications, [ :status, :due_on ]
  end
end
