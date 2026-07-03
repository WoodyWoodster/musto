class CreateOnboardingTasks < ActiveRecord::Migration[8.1]
  def change
    create_table :onboarding_tasks do |t|
      t.references :employee, null: false, foreign_key: true
      t.string :title, null: false
      t.string :category, null: false
      t.string :status, null: false, default: "open"
      t.date :due_on, null: false
      t.datetime :completed_at
      t.string :owner, null: false, default: "people"
      t.json :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :onboarding_tasks, [ :employee_id, :status ]
    add_index :onboarding_tasks, [ :due_on, :status ]
  end
end
