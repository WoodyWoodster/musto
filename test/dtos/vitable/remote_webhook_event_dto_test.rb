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

    test "normalizes nested remote webhook event envelopes with resource objects" do
      occurred_at = Time.current.change(usec: 0)

      dto = RemoteWebhookEventDto.from_remote_event(
        "data" => {
          "webhook_event" => {
            "id" => "wevt_remote_webhook_nested",
            "organization" => {
              "id" => "org_remote_nested"
            },
            "type" => "employee.eligibility_granted",
            "resource" => {
              "type" => "employee",
              "id" => "empl_remote_123"
            },
            "timestamp" => occurred_at.iso8601
          }
        }
      )

      assert_equal "wevt_remote_webhook_nested", dto.event_id
      assert_equal "org_remote_nested", dto.organization_id
      assert_equal "employee.eligibility_granted", dto.event_name
      assert_equal "employee", dto.resource_type
      assert_equal "empl_remote_123", dto.resource_id
      assert_equal occurred_at.to_i, dto.occurred_at.to_i
      assert_equal "wevt_remote_webhook_nested", dto.to_snapshot_hash.fetch("event_id")
      assert_equal "org_remote_nested", dto.to_snapshot_hash.fetch("organization_id")
      assert_equal "wevt_remote_webhook_nested", dto.raw_payload.dig("data", "webhook_event", "id")
    end

    test "extracts nested event ids for sparse list records" do
      assert_equal "wevt_sparse", RemoteWebhookEventDto.remote_event_id("data" => { "id" => "wevt_sparse" })
      assert_equal "wevt_sparse_event", RemoteWebhookEventDto.remote_event_id(
        "data" => {
          "webhook_event" => {
            "id" => "wevt_sparse_event"
          }
        }
      )
      assert_nil RemoteWebhookEventDto.from_remote_event("data" => { "id" => "wevt_sparse" })
    end
  end
end
