require "test_helper"

module Vitable
  class RemoteEmployerSettingsResponseDtoTest < ActiveSupport::TestCase
    test "normalizes flat and nested settings responses" do
      flat = RemoteEmployerSettingsResponseDto
        .from_hash("pay_frequency" => "bi_weekly")
        .validate!(expected_pay_frequency: "bi_weekly")
      nested = RemoteEmployerSettingsResponseDto
        .from_hash("data" => { "employer_settings" => { "pay_frequency" => "semi_monthly" } })
        .validate!(expected_pay_frequency: "semi_monthly")

      assert_equal "bi_weekly", flat.pay_frequency
      assert_equal({ "pay_frequency" => "bi_weekly" }, flat.to_metadata)
      assert_equal "semi_monthly", nested.pay_frequency
      assert_equal({ "pay_frequency" => "semi_monthly" }, nested.to_metadata)
    end

    test "validates expected pay frequency" do
      error = assert_raises(ArgumentError) do
        RemoteEmployerSettingsResponseDto
          .from_hash("data" => { "settings" => { "pay_frequency" => "monthly" } })
          .validate!(expected_pay_frequency: "bi_weekly")
      end

      assert_equal "Vitable employer settings response returned pay_frequency monthly, expected bi_weekly", error.message
    end
  end
end
