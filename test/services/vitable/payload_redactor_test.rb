require "test_helper"

module Vitable
  class PayloadRedactorTest < ActiveSupport::TestCase
    test "redacts Vitable-prefixed secrets from free text errors" do
      message = PayloadRedactor.error_message(
        StandardError.new(
          "remote error included vit_apk_plain_secret, vit_at_plain_secret, and vit_rt_plain_secret"
        )
      )

      assert_equal(
        "remote error included [FILTERED], [FILTERED], and [FILTERED]",
        message
      )
      assert_not_includes message, "vit_apk_plain_secret"
      assert_not_includes message, "vit_at_plain_secret"
      assert_not_includes message, "vit_rt_plain_secret"
    end

    test "redacts JSON string IO API error bodies" do
      error = Struct.new(:status, :body, :message).new(
        400,
        StringIO.new(JSON.generate(error: { message: "Invalid payload", api_key: "vit_apk_plain_secret" })),
        "fallback message"
      )

      message = PayloadRedactor.error_message(error)

      assert_includes message, "Vitable API request failed with status 400"
      assert_includes message, "Invalid payload"
      assert_not_includes message, "vit_apk_plain_secret"
      assert_includes message, "[FILTERED]"
    end
  end
end
