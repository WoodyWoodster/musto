class AddLifecycleFieldsToEmployeeDocuments < ActiveRecord::Migration[8.1]
  def change
    add_column :employee_documents, :requested_at, :datetime
    add_column :employee_documents, :verified_at, :datetime
    add_column :employee_documents, :source, :string, default: "employee_portal", null: false

    add_index :employee_documents, [ :status, :requested_at ]
    add_index :employee_documents, [ :status, :verified_at ]
    add_index :employee_documents, :source
  end
end
