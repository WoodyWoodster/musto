class CreateComplianceNotices < ActiveRecord::Migration[8.1]
  def change
    create_table :compliance_notices do |t|
      t.references :employer, null: false, foreign_key: true
      t.references :employee, foreign_key: true
      t.string :source, null: false
      t.string :notice_type, null: false
      t.string :title, null: false
      t.string :agency_name, null: false
      t.string :jurisdiction, null: false
      t.string :reference_number
      t.string :severity, default: "medium", null: false
      t.string :status, default: "received", null: false
      t.date :received_on, null: false
      t.date :due_on, null: false
      t.integer :amount_cents, default: 0, null: false
      t.string :response_owner, default: "Compliance", null: false
      t.string :response_channel, default: "agency_portal", null: false
      t.text :summary
      t.text :resolution_summary
      t.datetime :acknowledged_at
      t.datetime :responded_at
      t.datetime :resolved_at
      t.json :metadata, default: {}, null: false
      t.timestamps

      t.index [ :employer_id, :status ]
      t.index [ :employer_id, :notice_type ]
      t.index [ :status, :due_on ]
      t.index [ :agency_name, :reference_number ]
      t.index [ :severity, :due_on ]
    end
  end
end
