require "test_helper"

class TrainingProgramTest < ActiveSupport::TestCase
  setup do
    organization = Organization.create!(name: "Training Org", external_id: "training_org")
    @employer = organization.employers.create!(name: "Training Employer", status: "active")
    @employee = @employer.employees.create!(first_name: "Casey", last_name: "Ng", email: "casey.training@example.com")
  end

  test "launches program with audit metadata" do
    program = @employer.training_programs.create!(title: "Security basics", category: "security", due_on: Date.current + 14.days)

    program.launch!(requested_by: "people_ops")

    assert program.active?
    assert_equal "people_ops", program.metadata.fetch("launched_by")
    assert_not_nil program.launched_at
  end

  test "refreshes assignment counters" do
    program = @employer.training_programs.create!(title: "Compliance basics", due_on: Date.current + 14.days)
    program.training_assignments.create!(employee: @employee, status: "complete", due_on: Date.current + 14.days, completed_at: 1.day.ago, certificate_id: "TRN-1")

    program.refresh_counts!

    assert_equal 1, program.required_count
    assert_equal 1, program.completed_count
    assert_equal 0, program.overdue_count
  end
end
