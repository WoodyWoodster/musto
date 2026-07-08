require "test_helper"

module Vitable
  class WebhookEventDtoTest < ActiveSupport::TestCase
    test "normalizes nested webhook event envelopes" do
      occurred_at = Time.current.change(usec: 0)

      dto = WebhookEventDto.from_payload(
        data: {
          webhook_event: {
            id: "wevt_nested_webhook",
            organization: {
              id: "org_webhook_test"
            },
            type: "employee.eligibility_granted",
            resource: {
              type: "employee",
              id: "empl_123"
            },
            timestamp: occurred_at.iso8601
          }
        }
      )

      assert_equal "wevt_nested_webhook", dto.event_id
      assert_equal "org_webhook_test", dto.organization_external_id
      assert_equal "employee.eligibility_granted", dto.event_name
      assert_equal "employee", dto.resource_type
      assert_equal "empl_123", dto.resource_id
      assert_equal occurred_at.to_i, dto.occurred_at.to_i
      assert_equal "wevt_nested_webhook", dto.payload.fetch(:event_id)
      assert_equal "org_webhook_test", dto.payload.fetch(:organization_id)
      assert_equal "employee.eligibility_granted", dto.payload.fetch(:event_name)
      assert_equal "employee", dto.payload.fetch(:resource_type)
      assert_equal "empl_123", dto.payload.fetch(:resource_id)
      assert_equal "wevt_nested_webhook", dto.payload.dig(:data, :webhook_event, :id)
    end
  end
end
