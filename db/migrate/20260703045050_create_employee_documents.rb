class CreateEmployeeDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :employee_documents do |t|
      t.references :employee, null: false, foreign_key: true
      t.string :title, null: false
      t.string :document_type, null: false
      t.string :status, null: false, default: "pending"
      t.date :issued_on
      t.date :expires_on
      t.json :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :employee_documents, [ :employee_id, :document_type ]
    add_index :employee_documents, [ :status, :expires_on ]
  end
end
