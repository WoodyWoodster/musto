require "test_helper"

module Vitable
  class RemoteEligibilityPolicyResponseDtoTest < ActiveSupport::TestCase
    test "normalizes nested eligibility policy responses" do
      dto = RemoteEligibilityPolicyResponseDto
        .from_hash(
          "data" => {
            "benefit_eligibility_policy" => {
              "policy_id" => "elig_policy_nested",
              "employer" => { "id" => "empr_remote_123" },
              "classification" => "All"
            }
          }
        )
        .validate!(expected_employer_id: "empr_remote_123")

      assert_equal "elig_policy_nested", dto.remote_policy_id
      assert_equal "empr_remote_123", dto.remote_employer_id
      assert_equal "elig_policy_nested", dto.to_snapshot_hash.fetch("id")
      assert_equal "empr_remote_123", dto.to_snapshot_hash.fetch("employer_id")
    end

    test "validates remote employer identity" do
      error = assert_raises(ArgumentError) do
        RemoteEligibilityPolicyResponseDto
          .from_hash("data" => { "eligibility_policy" => { "id" => "elig_policy_123", "employer_id" => "empr_other" } })
          .validate!(expected_employer_id: "empr_expected")
      end

      assert_equal "Vitable eligibility policy response returned remote employer ID empr_other, expected empr_expected", error.message
    end
  end
end
