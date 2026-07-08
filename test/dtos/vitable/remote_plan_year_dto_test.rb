require "test_helper"

module Vitable
  class RemotePlanYearDtoTest < ActiveSupport::TestCase
    test "normalizes flat and wrapped plan year payloads" do
      flat_payload = {
        "id" => "pyear_remote_2026",
        "employer_id" => "empr_remote_123",
        "plan_year" => 2026,
        "starts_on" => "2026-01-01",
        "ends_on" => "2026-12-31",
        "status" => "active"
      }
      wrapped_payload = {
        "data" => {
          "id" => "pyear_remote_2027",
          "employer" => { "id" => "empr_remote_123", "reference_id" => "musto_employer_42" },
          "coverage_year" => "2027",
          "coverage_start" => "2027-01-01",
          "coverage_end" => "2027-12-31"
        }
      }

      flat = RemotePlanYearDto.from_hash(flat_payload)
      wrapped = RemotePlanYearDto.from_hash(wrapped_payload)

      assert_equal "pyear_remote_2026", flat.remote_plan_year_id
      assert_equal "empr_remote_123", flat.remote_employer_id
      assert_equal 2026, flat.year
      assert_equal Date.new(2026, 1, 1), flat.starts_on
      assert_equal "pyear_remote_2027", wrapped.remote_plan_year_id
      assert_equal "musto_employer_42", wrapped.employer_reference_id
      assert_equal 2027, wrapped.year
      assert_equal "2027-12-31", wrapped.snapshot_hash.fetch("ends_on")
    end
  end
end
