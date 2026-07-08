require "test_helper"

module Vitable
  class RemoteEmployeeDtoTest < ActiveSupport::TestCase
    test "normalizes remote employee identity and metadata" do
      dto = RemoteEmployeeDto.from_hash(
        "id" => "empl_remote_123",
        "reference_id" => "musto_employee_42",
        "email" => "casey@example.com",
        "status" => "active",
        "member_id" => "mem_remote_123",
        "employee_class" => "Full Time",
        "hire_date" => "2025-01-06",
        "date_of_birth" => "1990-04-09",
        "phone" => "+15551231234",
        "address" => {
          "line1" => "100 Market St",
          "line2" => "Suite 400",
          "city" => "Philadelphia",
          "state" => "PA",
          "postal_code" => "19107"
        },
        "deductions" => [
          { "id" => "ded_123", "deduction_amount_in_cents" => 4500 }
        ]
      ).validate_identity!(response_label: "Vitable remote roster employee")

      metadata = dto.metadata(
        source: "vitable_remote_roster",
        refreshed_at: "2026-07-08T12:00:00Z",
        census_sync_status: "synced"
      )

      assert_equal "empl_remote_123", dto.remote_employee_id
      assert_equal "active", dto.local_employment_status
      assert_equal Date.new(2025, 1, 6), dto.hire_date
      assert_equal "synced", metadata.fetch("vitable_census_sync_status")
      assert_equal "Full Time", metadata.fetch("vitable_remote_employee_class")
      assert_equal "2025-01-06", metadata.fetch("vitable_remote_hire_date")
      assert_equal "1990-04-09", metadata.fetch("vitable_remote_date_of_birth")
      assert_equal(
        {
          "address_line_1" => "100 Market St",
          "address_line_2" => "Suite 400",
          "city" => "Philadelphia",
          "state" => "PA",
          "zipcode" => "19107"
        },
        metadata.fetch("vitable_remote_address")
      )
      assert_equal "Full Time", metadata.dig("vitable_last_resource_snapshot", "employee_class")
    end

    test "raises with the caller supplied response label for missing identity" do
      error = assert_raises(ArgumentError) do
        RemoteEmployeeDto
          .from_hash("member_id" => "mem_missing_employee_id", "email" => "casey@example.com")
          .validate_identity!(response_label: "Vitable API snapshot employee")
      end

      assert_equal "Vitable API snapshot employee casey@example.com did not include a remote employee ID", error.message
    end
  end
end
