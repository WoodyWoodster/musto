require "test_helper"

class EmployeeGoalTest < ActiveSupport::TestCase
  setup do
    organization = Organization.create!(name: "Goal Org", external_id: "goal_org")
    employer = organization.employers.create!(name: "Goal Employer", status: "active")
    @employee = employer.employees.create!(first_name: "Casey", last_name: "Ng", email: "casey.goal@example.com")
  end

  test "completes goal with audit metadata" do
    goal = @employee.employee_goals.create!(title: "Improve payroll accuracy", due_on: Date.current + 30.days, progress_percent: 80)

    goal.complete!(reviewed_by: "manager")

    assert goal.complete?
    assert_equal 100, goal.progress_percent
    assert_equal "manager", goal.metadata.fetch("completed_by")
    assert_not_nil goal.completed_at
  end

  test "requires progress within percentage range" do
    goal = @employee.employee_goals.build(title: "Invalid progress", due_on: Date.current + 30.days, progress_percent: 140)

    assert_not goal.valid?
    assert_includes goal.errors[:progress_percent], "must be less than or equal to 100"
  end
end
