class CreateOpenEnrollmentCampaigns < ActiveRecord::Migration[8.1]
  def change
    create_table :open_enrollment_campaigns do |t|
      t.references :employer, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :plan_year, null: false
      t.date :starts_on, null: false
      t.date :ends_on, null: false
      t.string :status, null: false, default: "draft"
      t.datetime :launched_at
      t.datetime :reminders_sent_at
      t.json :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :open_enrollment_campaigns, [ :employer_id, :plan_year ], unique: true
    add_index :open_enrollment_campaigns, [ :status, :starts_on ]

    create_table :open_enrollment_invitations do |t|
      t.references :open_enrollment_campaign, null: false, foreign_key: true
      t.references :employee, null: false, foreign_key: true
      t.string :status, null: false, default: "not_sent"
      t.date :due_on, null: false
      t.datetime :sent_at
      t.datetime :opened_at
      t.datetime :completed_at
      t.datetime :last_reminded_at
      t.json :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :open_enrollment_invitations, [ :open_enrollment_campaign_id, :employee_id ], unique: true, name: "idx_open_enrollment_invites_on_campaign_employee"
    add_index :open_enrollment_invitations, [ :status, :due_on ]
  end
end
