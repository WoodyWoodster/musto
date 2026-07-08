require "test_helper"

module Vitable
  class RemoteCensusSyncResponseDtoTest < ActiveSupport::TestCase
    test "normalizes nested census sync responses" do
      accepted_at = Time.current.change(usec: 0)

      dto = RemoteCensusSyncResponseDto
        .from_hash(
          "data" => {
            "census_sync_request" => {
              "employer" => { "id" => "empr_remote_123" },
              "created_at" => accepted_at.iso8601,
              "employee_count" => 12
            }
          }
        )
        .validate!(expected_employer_id: "empr_remote_123")

      assert_equal "empr_remote_123", dto.remote_employer_id
      assert_equal accepted_at.iso8601, dto.accepted_at
      assert_equal "empr_remote_123", dto.raw_payload.fetch("employer_id")
      assert_equal accepted_at.iso8601, dto.raw_payload.fetch("accepted_at")
    end

    test "validates employer identity" do
      error = assert_raises(ArgumentError) do
        RemoteCensusSyncResponseDto
          .from_hash("data" => { "census_sync" => { "employer_id" => "empr_other", "accepted_at" => "2026-07-08T10:00:00Z" } })
          .validate!(expected_employer_id: "empr_expected")
      end

      assert_equal "Vitable census sync response returned remote employer ID empr_other, expected empr_expected", error.message
    end
  end
end
