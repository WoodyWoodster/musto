require "test_helper"

module Vitable
  class RemoteWebhookEventDtoTest < ActiveSupport::TestCase
    test "normalizes nested remote event envelopes" do
      occurred_at = Time.current.change(usec: 0)

      dto = RemoteWebhookEventDto.from_remote_event(
        "data" => {
          "id" => "wevt_remote_nested",
          "organization_external_id" => "org_remote_123",
          "event_name" => "dependent.updated",
          "resource_type" => "dependent",
          "resource_id" => "dep_remote_123",
          "created_at" => occurred_at.iso8601
        }
      )

      assert_equal "wevt_remote_nested", dto.event_id
      assert_equal "org_remote_123", dto.organization_id
      assert_equal "dependent.updated", dto.event_name
      assert_equal "dependent", dto.resource_type
      assert_equal "dep_remote_123", dto.resource_id
      assert_equal occurred_at.to_i, dto.occurred_at.to_i
      assert_equal "wevt_remote_nested", dto.to_snapshot_hash.fetch("event_id")
    end

    test "extracts nested event ids for sparse list records" do
      assert_equal "wevt_sparse", RemoteWebhookEventDto.remote_event_id("data" => { "id" => "wevt_sparse" })
      assert_nil RemoteWebhookEventDto.from_remote_event("data" => { "id" => "wevt_sparse" })
    end
  end
end
