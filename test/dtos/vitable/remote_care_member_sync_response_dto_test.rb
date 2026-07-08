require "test_helper"

module Vitable
  class RemoteCareMemberSyncResponseDtoTest < ActiveSupport::TestCase
    test "normalizes nested submit responses" do
      accepted_at = Time.current.change(usec: 0)

      dto = RemoteCareMemberSyncResponseDto
        .from_hash(
          "data" => {
            "group_member_sync_request" => {
              "id" => "grpmsr_remote_123",
              "group" => { "id" => "grp_remote_123" },
              "created_at" => accepted_at.iso8601
            }
          }
        )
        .validate_submit!(expected_group_id: "grp_remote_123")

      assert_equal "grpmsr_remote_123", dto.request_id
      assert_equal "grp_remote_123", dto.group_id
      assert_equal accepted_at.iso8601, dto.accepted_at
      assert_equal "grpmsr_remote_123", dto.raw_payload.fetch("request_id")
      assert_equal "grp_remote_123", dto.to_request_state(refreshed_at: accepted_at).fetch("group_id")
    end

    test "normalizes completed refresh responses" do
      dto = RemoteCareMemberSyncResponseDto
        .from_hash(
          "data" => {
            "member_sync" => {
              "request_id" => "grpmsr_remote_123",
              "group_id" => "grp_remote_123",
              "accepted_at" => "2026-07-08T10:00:00Z",
              "finished_at" => "2026-07-08T10:05:00Z",
              "result" => {
                "added_group_member_ids" => [ "grpmem_remote_123" ],
                "removed_group_member_ids" => [],
                "failures" => []
              }
            }
          }
        )
        .validate_refresh!(expected_group_id: "grp_remote_123", expected_request_id: "grpmsr_remote_123")

      assert_equal "2026-07-08T10:05:00Z", dto.completed_at
      assert_equal [ "grpmem_remote_123" ], dto.results.fetch("added_group_member_ids")
      assert_equal "complete", dto.to_request_state(refreshed_at: Time.zone.parse("2026-07-08T10:06:00Z")).fetch("status")
    end
  end
end
