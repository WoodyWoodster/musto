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
  end
end
