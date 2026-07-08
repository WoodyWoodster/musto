require "test_helper"

module Vitable
  class RemoteEnrollmentDtoTest < ActiveSupport::TestCase
    test "normalizes nested enrollment aliases" do
      answered_at = Time.current.change(usec: 0)

      dto = RemoteEnrollmentDto
        .from_hash(
          "data" => {
            "enrollment" => {
              "enrollment_id" => "enrl_remote_123",
              "member_id" => "empl_remote_123",
              "plan" => {
                "id" => "bprd_remote_dental",
                "name" => "Dental",
                "category" => "Dental",
                "product_code" => "VD"
              },
              "status" => "enrolled",
              "answered_at" => answered_at.iso8601,
              "coverage_start_date" => "2026-01-01",
              "deduction_amount_in_cents" => "4500",
              "employer_contribution_in_cents" => 500
            }
          }
        )
        .validate_identity!(response_label: "Vitable enrollment list response item 1")

      assert_equal "enrl_remote_123", dto.remote_id
      assert_equal "empl_remote_123", dto.remote_employee_id
      assert_equal "bprd_remote_dental", dto.remote_plan_id
      assert_equal "Dental", dto.benefit_name
      assert_equal "VD", dto.remote_product_code
      assert_equal "accepted", dto.local_status
      assert_equal answered_at.to_i, dto.answered_at.to_i
      assert_equal Date.new(2026, 1, 1), dto.coverage_start_on
      assert_equal 4500, dto.employee_deduction_cents
      assert_equal 500, dto.employer_contribution_cents
      assert_equal "bprd_remote_dental", dto.metadata.dig("vitable_remote_benefit", "id")
      assert_equal "enrl_remote_123", dto.metadata.dig("vitable_last_resource_snapshot", "enrollment_id")
    end

    test "validates normalized identity fields" do
      error = assert_raises(ArgumentError) do
        RemoteEnrollmentDto
          .from_hash("id" => "enrl_missing_plan", "member_id" => "empl_remote_123")
          .validate_identity!(response_label: "Vitable API snapshot enrollment")
      end

      assert_equal "Vitable API snapshot enrollment enrl_missing_plan did not include a remote benefit ID", error.message
    end
  end
end
