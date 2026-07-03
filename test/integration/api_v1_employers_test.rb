require "test_helper"

class ApiV1EmployersTest < ActionDispatch::IntegrationTest
  test "creates an employer through the command pipeline" do
    organization = Organization.create!(name: "Test Platform", external_id: "org_test_platform")

    post api_v1_employers_path,
      params: {
        employer: {
          organization_id: organization.id,
          name: "Beacon Bakery",
          legal_name: "Beacon Bakery LLC",
          ein: "98-7654321",
          settings: { pay_frequency: "weekly" }
        }
      },
      as: :json

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "Beacon Bakery", body.fetch("name")
    assert_equal 1, Employer.where(name: "Beacon Bakery").count
  end
end
