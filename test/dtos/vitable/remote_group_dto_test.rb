require "test_helper"

module Vitable
  class RemoteGroupDtoTest < ActiveSupport::TestCase
    test "normalizes remote group identity and snapshot metadata" do
      dto = RemoteGroupDto.from_hash(
        "data" => {
          "group" => {
            "group_id" => "grp_remote_123",
            "organization_external_id" => "org_remote_123",
            "reference_id" => "musto_care_group_42",
            "name" => "Ops Care Group",
            "created_at" => "2026-07-08T10:00:00Z",
            "updated_at" => "2026-07-08T11:00:00Z"
          }
        }
      ).validate_identity!(response_label: "Vitable API snapshot group")

      metadata = dto.settings_metadata(
        source: "vitable_api_snapshot",
        refreshed_at: "2026-07-08T12:00:00Z",
        matched_by: "external_reference_id"
      )

      assert_equal "grp_remote_123", dto.group_id
      assert_equal "musto_care_group_42", dto.external_reference_id
      assert_equal "org_remote_123", dto.organization_id
      assert_equal "external_reference_id", metadata.fetch("vitable_care_group_snapshot_matched_by")
      assert_equal "grp_remote_123", metadata.dig("vitable_care_group_snapshot", "id")
      assert_equal "musto_care_group_42", metadata.dig("vitable_care_group_snapshot", "external_reference_id")
    end

    test "validates care group response reference mismatches" do
      error = assert_raises(ArgumentError) do
        RemoteGroupDto
          .from_hash("data" => { "id" => "grp_remote_123", "reference_id" => "musto_care_group_wrong" })
          .validate_care_group_response!(
            expected_group_id: nil,
            expected_external_reference_id: "musto_care_group_42"
          )
      end

      assert_equal "Vitable care group response returned external_reference_id musto_care_group_wrong, expected musto_care_group_42", error.message
    end
  end
end
