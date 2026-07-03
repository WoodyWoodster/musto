require "test_helper"

class PerformanceReviewTest < ActiveSupport::TestCase
  setup do
    organization = Organization.create!(name: "Review Org", external_id: "review_org")
    employer = organization.employers.create!(name: "Review Employer", status: "active")
    @employee = employer.employees.create!(first_name: "Casey", last_name: "Ng", email: "casey.review@example.com")
    @cycle = employer.performance_cycles.create!(name: "Q3 Review", period_start_on: Date.current.beginning_of_quarter, period_end_on: Date.current.end_of_quarter, due_on: Date.current.end_of_quarter + 14.days)
  end

  test "identifies calibratable manager reviews" do
    review = @cycle.performance_reviews.create!(employee: @employee, status: "manager_review", rating: 4, due_on: Date.current + 7.days)

    assert review.calibratable?
    assert_not review.complete?
  end

  test "requires rating within review scale" do
    review = @cycle.performance_reviews.build(employee: @employee, status: "manager_review", rating: 7, due_on: Date.current + 7.days)

    assert_not review.valid?
    assert_includes review.errors[:rating], "must be less than or equal to 5"
  end
end
