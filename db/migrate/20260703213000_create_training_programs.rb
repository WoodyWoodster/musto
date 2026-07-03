class CreateTrainingPrograms < ActiveRecord::Migration[8.1]
  def change
    create_table :training_programs do |t|
      t.references :employer, null: false, foreign_key: true
      t.string :title, null: false
      t.string :category, null: false, default: "compliance"
      t.text :description
      t.string :audience, null: false, default: "all_employees"
      t.string :cadence, null: false, default: "annual"
      t.string :status, null: false, default: "draft"
      t.date :launch_on
      t.date :due_on, null: false
      t.datetime :launched_at
      t.datetime :closed_at
      t.integer :required_count, null: false, default: 0
      t.integer :completed_count, null: false, default: 0
      t.integer :overdue_count, null: false, default: 0
      t.json :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :training_programs, [ :employer_id, :status ]
    add_index :training_programs, [ :category, :due_on ]

    create_table :training_assignments do |t|
      t.references :training_program, null: false, foreign_key: true
      t.references :employee, null: false, foreign_key: true
      t.string :status, null: false, default: "assigned"
      t.date :due_on, null: false
      t.datetime :started_at
      t.datetime :completed_at
      t.integer :score
      t.string :certificate_id
      t.json :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :training_assignments, [ :training_program_id, :employee_id ], unique: true, name: "index_training_assignments_on_program_and_employee"
    add_index :training_assignments, [ :status, :due_on ]
    add_index :training_assignments, :certificate_id
  end
end
