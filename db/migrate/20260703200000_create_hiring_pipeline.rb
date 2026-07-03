class CreateHiringPipeline < ActiveRecord::Migration[8.1]
  def change
    create_table :job_openings do |t|
      t.references :employer, null: false, foreign_key: true
      t.references :department, foreign_key: true
      t.references :work_location, foreign_key: true
      t.string :title, null: false
      t.string :code, null: false
      t.text :description
      t.string :status, null: false, default: "open"
      t.string :employment_type, null: false, default: "full_time"
      t.integer :headcount, null: false, default: 1
      t.integer :compensation_min_cents, null: false, default: 0
      t.integer :compensation_max_cents, null: false, default: 0
      t.boolean :remote, null: false, default: false
      t.date :target_start_on
      t.json :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :job_openings, [ :employer_id, :code ], unique: true
    add_index :job_openings, [ :employer_id, :status ]
    add_index :job_openings, [ :status, :target_start_on ]

    create_table :candidates do |t|
      t.references :job_opening, null: false, foreign_key: true
      t.references :employee, foreign_key: true
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :email, null: false
      t.string :phone
      t.string :source, null: false, default: "direct"
      t.string :stage, null: false, default: "applied"
      t.integer :score, null: false, default: 0
      t.date :applied_on, null: false
      t.date :target_start_on
      t.integer :compensation_cents, null: false, default: 0
      t.datetime :offer_sent_at
      t.datetime :accepted_at
      t.datetime :hired_at
      t.datetime :rejected_at
      t.json :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :candidates, [ :job_opening_id, :email ], unique: true
    add_index :candidates, [ :stage, :applied_on ]
  end
end
