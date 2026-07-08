require "test_helper"

module Vitable
  class RemotePlanDtoTest < ActiveSupport::TestCase
    test "normalizes flat and nested remote plan payloads" do
      flat = RemotePlanDto
        .from_hash("id" => "bprd_remote_primary", "name" => "Primary Care")
        .validate!(response_label: "Vitable plan list response item 1")
      nested = RemotePlanDto
        .from_hash("data" => { "plan" => { "id" => "bprd_remote_dental", "name" => "Dental" } })
        .validate!(response_label: "Vitable plan retrieve response")

      assert_equal "bprd_remote_primary", flat.remote_plan_id
      assert_equal "Primary Care", flat.name
      assert_equal "bprd_remote_primary", flat.to_snapshot_hash.fetch("id")
      assert_equal "bprd_remote_dental", nested.remote_plan_id
      assert_equal "Dental", nested.to_snapshot_hash.fetch("name")
    end

    test "raises with the caller supplied response label for missing identity" do
      error = assert_raises(ArgumentError) do
        RemotePlanDto
          .from_hash("name" => "Primary Care")
          .validate!(response_label: "Vitable plan list response item 2")
      end

      assert_equal "Vitable plan list response item 2 Primary Care did not include a remote plan ID", error.message
    end
  end
end
