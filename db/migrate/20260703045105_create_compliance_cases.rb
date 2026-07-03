class CreateComplianceCases < ActiveRecord::Migration[8.1]
  def change
    create_table :compliance_cases do |t|
      t.references :employer, null: false, foreign_key: true
      t.references :employee, null: true, foreign_key: true
      t.string :kind, null: false
      t.string :severity, null: false, default: "medium"
      t.string :status, null: false, default: "open"
      t.date :due_on
      t.datetime :resolved_at
      t.text :description
      t.json :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :compliance_cases, [ :employer_id, :status ]
    add_index :compliance_cases, [ :severity, :due_on ]
  end
end
