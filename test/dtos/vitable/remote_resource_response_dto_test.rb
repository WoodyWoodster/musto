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

    test "normalizes nested employee resource envelopes" do
      dto = RemoteResourceResponseDto.from_response(
        {
          data: {
            employee: {
              id: "empl_123",
              member_id: "mem_123",
              email: "casey@example.com"
            }
          }
        },
        resource_type: "employee",
        resource_id: "empl_123"
      ).validate!

      assert_equal "empl_123", dto.attributes.fetch("id")
      assert_equal "mem_123", dto.attributes.fetch("member_id")
      assert_equal "casey@example.com", dto.attributes.fetch("email")
      assert_not dto.attributes.key?("employee")
    end

    test "normalizes top-level resource envelopes" do
      dto = RemoteResourceResponseDto.from_response(
        {
          resource: {
            id: "grp_123",
            external_reference_id: "musto_care_group_1",
            name: "Care Group"
          }
        },
        resource_type: "group",
        resource_id: "grp_123"
      ).validate!

      assert_equal "grp_123", dto.attributes.fetch("id")
      assert_equal "musto_care_group_1", dto.attributes.fetch("external_reference_id")
      assert_equal "Care Group", dto.attributes.fetch("name")
    end

    test "normalizes webhook event aliases" do
      dto = RemoteResourceResponseDto.from_response(
        {
          data: {
            event: {
              id: "wevt_123",
              organization_id: "org_123",
              event_name: "enrollment.accepted",
              resource_type: "enrollment",
              resource_id: "enrl_123",
              created_at: "2026-07-08T10:00:00Z"
            }
          }
        },
        resource_type: "webhook_event",
        resource_id: "wevt_123"
      ).validate!

      assert_equal "wevt_123", dto.attributes.fetch("id")
      assert_equal "enrollment.accepted", dto.attributes.fetch("event_name")
      assert_equal "enrl_123", dto.attributes.fetch("resource_id")
    end

    test "rejects arrays for supported resource responses" do
      error = assert_raises(ArgumentError) do
        RemoteResourceResponseDto
          .from_response({ data: [ { id: "empl_123" } ] }, resource_type: "employee", resource_id: "empl_123")
          .validate!
      end

      assert_equal "Vitable employee fetch response returned a data array; expected a single resource object", error.message
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
