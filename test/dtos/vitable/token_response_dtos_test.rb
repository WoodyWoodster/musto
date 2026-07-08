require "test_helper"

module Vitable
  class TokenResponseDtosTest < ActiveSupport::TestCase
    test "widget token response accepts data wrapped token responses" do
      issued_at = Time.current
      dto = WidgetTokenResponseDto.from_response(
        {
          "data" => {
            "access_token" => "vit_at_wrapped_widget",
            "expires_in" => 3_600,
            "token_type" => "Bearer",
            "bound_entity" => { "type" => "employer", "id" => "empr_wrapped" }
          }
        },
        issued_at:
      )

      assert_equal "vit_at_wrapped_widget", dto.access_token
      assert_equal 3_600, dto.expires_in
      assert_equal "empr_wrapped", dto.bound_entity.fetch("id")
      assert_equal true, dto.to_metadata.fetch("token_present")
      assert_equal issued_at.iso8601, dto.to_h.fetch("issued_at")
    end

    test "admin and embedded issuance DTOs accept data wrapped token responses" do
      issued_at = Time.current
      response = {
        "data" => {
          "access_token" => "vit_at_wrapped_session",
          "expires_in" => 3_600,
          "token_type" => "Bearer",
          "bound_entity" => { "type" => "employee", "id" => "empl_wrapped" }
        }
      }

      admin = AdminSessionIssuanceDto.from_response(response, issued_at:, sync_run_id: 42)
      embedded = EmbeddedSessionIssuanceDto.from_response(response, issued_at:, sync_run_id: 43)

      assert_equal true, admin.token_present
      assert_equal "empl_wrapped", admin.bound_entity.fetch("id")
      assert_equal 42, admin.sync_run_id
      assert admin.active?(at: issued_at + 5.minutes)

      assert_equal true, embedded.token_present
      assert_equal "empl_wrapped", embedded.bound_entity.fetch("id")
      assert_equal 43, embedded.sync_run_id
      assert_equal 3_600, embedded.expires_in
    end

    test "token response DTOs reject non-integer expiry values" do
      issued_at = Time.current
      response = {
        "data" => {
          "access_token" => "vit_at_wrapped_session",
          "expires_in" => "3600abc",
          "token_type" => "Bearer",
          "bound_entity" => { "type" => "employee", "id" => "empl_wrapped" }
        }
      }

      widget = WidgetTokenResponseDto.from_response(response, issued_at:)
      admin = AdminSessionIssuanceDto.from_response(response, issued_at:, sync_run_id: 42)
      embedded = EmbeddedSessionIssuanceDto.from_response(response, issued_at:, sync_run_id: 43)
      verification = RemoteAccessTokenResponseDto.from_response(response)

      error = assert_raises(ArgumentError) do
        widget.validate!(expected_type: "employee", expected_id: "empl_wrapped")
      end
      assert_match "invalid expires_in 3600abc", error.message

      error = assert_raises(ArgumentError) do
        admin.validate!(expected_type: "employee", expected_id: "empl_wrapped")
      end
      assert_match "invalid expires_in 3600abc", error.message

      error = assert_raises(ArgumentError) do
        embedded.validate!(expected_type: "employee", expected_id: "empl_wrapped")
      end
      assert_match "invalid expires_in 3600abc", error.message

      error = assert_raises(ArgumentError) do
        verification.validate!
      end
      assert_match "invalid expires_in 3600abc", error.message
    end
  end
end
