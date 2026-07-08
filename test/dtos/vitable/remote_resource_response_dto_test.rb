require "test_helper"

module Vitable
  class RemoteResourceResponseDtoTest < ActiveSupport::TestCase
    test "normalizes benefit eligibility policy resource responses" do
      dto = RemoteResourceResponseDto.from_response(
        {
          data: {
            id: "elig_policy_123",
            employer_id: "empr_123",
            waiting_period: "30 days",
            classification: "All"
          }
        },
        resource_type: "benefit_eligibility_policy",
        resource_id: "elig_policy_123"
      ).validate!

      assert dto.supported_resource_type?
      assert_equal "elig_policy_123", dto.attributes.fetch("id")
      assert_equal "empr_123", dto.attributes.fetch("employer_id")
    end

    test "rejects empty supported benefit eligibility policy responses" do
      error = assert_raises(ArgumentError) do
        RemoteResourceResponseDto
          .from_response({ data: {} }, resource_type: "eligibility_policy", resource_id: "elig_policy_empty")
          .validate!
      end

      assert_match "Vitable eligibility_policy fetch response did not include resource attributes", error.message
    end
  end
end
