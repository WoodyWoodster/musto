require "test_helper"

module Vitable
  class RemoteEmployerDtoTest < ActiveSupport::TestCase
    test "normalizes remote employer identity status and profile metadata" do
      dto = RemoteEmployerDto.from_hash(
        "data" => {
          "employer" => {
            "id" => "empr_remote_123",
            "organization_external_id" => "org_remote_123",
            "external_reference_id" => "musto_employer_42",
            "name" => "Ops Employer",
            "legal_name" => "Ops Employer LLC",
            "ein" => "XX-XXX6789",
            "email" => "benefits@example.com",
            "phone" => "4155550100",
            "active" => true,
            "address" => {
              "line1" => "214 Market Street",
              "line2" => "Floor 3",
              "city" => "San Francisco",
              "state" => "CA",
              "postal_code" => "94105"
            }
          }
        }
      ).validate_identity!(response_label: "Vitable API snapshot employer")

      metadata = dto.settings_metadata(
        source: "vitable_api_snapshot",
        refreshed_at: "2026-07-08T12:00:00Z",
        matched_by: "reference_id"
      )

      assert_equal "empr_remote_123", dto.remote_employer_id
      assert_equal "org_remote_123", dto.organization_id
      assert_equal "musto_employer_42", dto.reference_id
      assert_equal "active", dto.remote_status
      assert_equal "4155550100", dto.phone_number
      assert_equal "reference_id", metadata.fetch("vitable_last_snapshot_matched_by")
      assert_equal "214 Market Street", metadata.dig("vitable_remote_employer", "address", "address_line_1")
      assert_equal "94105", metadata.dig("vitable_remote_employer", "address", "zipcode")
    end

    test "validates create response reference mismatches" do
      error = assert_raises(ArgumentError) do
        RemoteEmployerDto
          .from_hash("data" => { "id" => "empr_remote_123", "reference_id" => "musto_employer_wrong" })
          .validate_create!(expected_reference_id: "musto_employer_42")
      end

      assert_equal "Vitable employer create response returned reference_id musto_employer_wrong, expected musto_employer_42", error.message
    end
  end
end
