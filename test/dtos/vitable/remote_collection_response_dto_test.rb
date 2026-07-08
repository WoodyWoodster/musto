require "test_helper"

module Vitable
  class RemoteCollectionResponseDtoTest < ActiveSupport::TestCase
    test "normalizes direct array responses" do
      dto = RemoteCollectionResponseDto.from_response(
        [
          { id: "empl_123", email: "casey@example.com" },
          { id: "empl_456", email: "jordan@example.com" }
        ],
        response_label: "Vitable employee list response"
      )

      assert_equal 2, dto.records.count
      assert_equal "empl_123", dto.records.first.fetch("id")
      assert_equal "jordan@example.com", dto.records.second.fetch("email")
      assert_equal 2, dto.raw_payload.fetch("data").count
    end

    test "normalizes nested collection envelopes" do
      dto = RemoteCollectionResponseDto.from_response(
        {
          data: {
            items: [
              { id: "wevt_123", resource_type: "enrollment" }
            ],
            page: { next: nil }
          }
        },
        response_label: "Vitable webhook event list response"
      )

      assert_equal 1, dto.records.count
      assert_equal "wevt_123", dto.records.first.fetch("id")
      assert_equal "enrollment", dto.records.first.fetch("resource_type")
    end

    test "normalizes alternate list keys" do
      dto = RemoteCollectionResponseDto.from_response(
        {
          records: [
            { id: "bprd_123", name: "Primary Care" }
          ]
        },
        response_label: "Vitable plan list response"
      )

      assert_equal "bprd_123", dto.records.sole.fetch("id")
    end

    test "rejects scalar collection items" do
      error = assert_raises(ArgumentError) do
        RemoteCollectionResponseDto.from_response(
          { data: [ "not-a-resource" ] },
          response_label: "Vitable employer list response"
        )
      end

      assert_equal "Vitable employer list response item 1 was not a resource object", error.message
    end

    test "rejects responses without a collection" do
      error = assert_raises(ArgumentError) do
        RemoteCollectionResponseDto.from_response(
          { meta: { total: 0 } },
          response_label: "Vitable group list response"
        )
      end

      assert_equal "Vitable group list response did not include a data array", error.message
    end
  end
end
