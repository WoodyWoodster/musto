require "test_helper"

module Vitable
  class CertificationMatrixTest < ActiveSupport::TestCase
    test "has a certification case for every endpoint catalog row" do
      certified_endpoints = CertificationMatrix.cases.map { |entry| entry.fetch(:endpoint) }

      EndpointCatalog.coverage_catalog.each do |entry|
        assert_includes certified_endpoints, entry.fetch(:fetch_path), "#{entry.fetch(:resource_type)} is not certified"
      end
    end

    test "maps every installed SDK method covered by the gateway" do
      certified_pairs = CertificationMatrix.sdk_method_pairs
      expected_pairs = ClientGateway::SDK_METHOD_COVERAGE.flat_map do |entry|
        entry.fetch(:sdk_methods).map { |method| [ entry.fetch(:resource_class).name, method.to_s ] }
      end.uniq

      expected_pairs.each do |pair|
        assert_includes certified_pairs, pair, "#{pair.join("#")} is not represented in certification"
      end
    end
  end
end
