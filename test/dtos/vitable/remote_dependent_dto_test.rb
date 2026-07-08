require "test_helper"

module Vitable
  class RemoteDependentDtoTest < ActiveSupport::TestCase
    test "normalizes nested dependent envelopes with employee context" do
      dto = RemoteDependentDto.from_hash(
        "data" => {
          "employee" => {
            "id" => "empl_remote_casey",
            "email" => "casey@example.com"
          },
          "employee_reference_id" => "musto_employee_42",
          "dependent" => {
            "dependent_id" => "dep_remote_harper",
            "external_reference_id" => "musto_dependent_84",
            "first_name" => "Harper",
            "last_name" => "Ng",
            "relationship_type" => "child",
            "dob" => "2018-03-04",
            "status" => "active",
            "verification_status" => "verified"
          }
        }
      )

      assert_equal "dep_remote_harper", dto.remote_id
      assert_equal "empl_remote_casey", dto.remote_employee_id
      assert_equal "musto_dependent_84", dto.reference_id
      assert_equal "Harper", dto.first_name
      assert_equal "Ng", dto.last_name
      assert_equal "child", dto.relationship
      assert_equal Date.new(2018, 3, 4), dto.date_of_birth
      assert_equal "enrolled", dto.enrollment_status
      assert_equal "eligible", dto.eligibility_status
      assert_equal "musto_employee_42", dto.raw_payload.fetch("employee_reference_id")
      assert_equal "casey@example.com", dto.raw_payload.dig("employee", "email")
    end

    test "reports missing required fields after normalization" do
      dto = RemoteDependentDto.from_hash("dependent" => { "id" => "dep_missing_name" })

      assert_equal [ "first_name", "last_name", "relationship" ], dto.missing_required_fields
    end
  end
end
