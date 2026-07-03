require "test_helper"

class TrainingAssignmentTest < ActiveSupport::TestCase
  setup do
    organization = Organization.create!(name: "Assignment Org", external_id: "assignment_org")
    employer = organization.employers.create!(name: "Assignment Employer", status: "active")
    @employee = employer.employees.create!(first_name: "Casey", last_name: "Ng", email: "casey.assignment@example.com")
    @program = employer.training_programs.create!(title: "Compliance basics", due_on: Date.current + 14.days)
  end

  test "completes assignment with certificate metadata" do
    assignment = @program.training_assignments.create!(employee: @employee, due_on: Date.current + 14.days)

    assignment.complete!(completed_by: "people_ops", score: 97)

    assert assignment.complete?
    assert_equal 97, assignment.score
    assert_equal "people_ops", assignment.metadata.fetch("completed_by")
    assert_not_nil assignment.completed_at
    assert_not_nil assignment.certificate_id
  end

  test "requires score within percentage range" do
    assignment = @program.training_assignments.build(employee: @employee, due_on: Date.current + 14.days, score: 120)

    assert_not assignment.valid?
    assert_includes assignment.errors[:score], "must be less than or equal to 100"
  end
end
