require "test_helper"

class ApplicationRepositoryTest < ActiveSupport::TestCase
  ProbeRepository = Class.new(ApplicationRepository) do
    def connection_for(organization)
      send(:vitable_connection_for, organization)
    end
  end

  setup do
    @previous_environment = ENV.fetch("VITABLE_CONNECT_ENVIRONMENT", nil)
    ENV.delete("VITABLE_CONNECT_ENVIRONMENT")
  end

  teardown do
    if @previous_environment
      ENV["VITABLE_CONNECT_ENVIRONMENT"] = @previous_environment
    else
      ENV.delete("VITABLE_CONNECT_ENVIRONMENT")
    end
  end

  test "default demo targeting does not fall back to a production connection" do
    organization = Organization.create!(name: "Demo Target Org", external_id: "org_demo_target")
    organization.integration_connections.create!(provider: "vitable", environment: "production")

    assert_nil ProbeRepository.new.connection_for(organization)
  end

  test "explicit production targeting can select a production connection" do
    ENV["VITABLE_CONNECT_ENVIRONMENT"] = "production"
    organization = Organization.create!(name: "Production Target Org", external_id: "org_production_target")
    production = organization.integration_connections.create!(provider: "vitable", environment: "production")
    organization.integration_connections.create!(provider: "vitable", environment: "demo")

    assert_equal production, ProbeRepository.new.connection_for(organization)
  end
end
