class CreateContractorPayments < ActiveRecord::Migration[8.1]
  def change
    create_table :contractor_payments do |t|
      t.references :contractor, null: false, foreign_key: true
      t.date :work_period_start_on, null: false
      t.date :work_period_end_on, null: false
      t.date :pay_date, null: false
      t.string :description, null: false
      t.integer :amount_cents, null: false, default: 0
      t.string :status, null: false, default: "draft"
      t.string :payment_method, null: false, default: "ach"
      t.datetime :approved_at
      t.datetime :scheduled_at
      t.datetime :paid_at
      t.json :metadata, null: false, default: {}
      t.timestamps

      t.index [ :contractor_id, :pay_date ]
      t.index [ :contractor_id, :status ]
      t.index [ :status, :pay_date ]
    end
  end
end
