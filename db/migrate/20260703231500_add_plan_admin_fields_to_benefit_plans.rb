class AddPlanAdminFieldsToBenefitPlans < ActiveRecord::Migration[8.1]
  def change
    add_column :benefit_plans, :plan_year, :integer
    add_column :benefit_plans, :effective_on, :date
    add_column :benefit_plans, :expires_on, :date
    add_column :benefit_plans, :employee_contribution_cents, :integer, default: 0, null: false
    add_column :benefit_plans, :employer_contribution_cents, :integer, default: 0, null: false
    add_column :benefit_plans, :contribution_strategy, :string, default: "fixed_employer_contribution", null: false
    add_column :benefit_plans, :eligibility_rule, :string, default: "active_full_time", null: false
    add_column :benefit_plans, :review_status, :string, default: "draft", null: false
    add_column :benefit_plans, :published_at, :datetime

    add_index :benefit_plans, [ :employer_id, :plan_year ]
    add_index :benefit_plans, :review_status
  end
end
