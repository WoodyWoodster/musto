class CreateCompensationChanges < ActiveRecord::Migration[8.1]
  def change
    create_table :compensation_changes do |t|
      t.references :employer, null: false, foreign_key: true
      t.references :employee, null: false, foreign_key: true
      t.references :payroll_run, foreign_key: true
      t.string :change_type, null: false
      t.string :status, null: false, default: "draft"
      t.string :reason, null: false
      t.integer :current_compensation_cents, null: false, default: 0
      t.integer :proposed_compensation_cents, null: false, default: 0
      t.integer :delta_cents, null: false, default: 0
      t.date :effective_on, null: false
      t.string :submitted_by
      t.datetime :submitted_at
      t.string :approved_by
      t.datetime :approved_at
      t.string :rejected_by
      t.datetime :rejected_at
      t.string :rejection_reason
      t.string :applied_by
      t.datetime :applied_at
      t.json :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :compensation_changes, [ :employer_id, :status ]
    add_index :compensation_changes, [ :employee_id, :effective_on ]
    add_index :compensation_changes, [ :status, :effective_on ]
  end
end
