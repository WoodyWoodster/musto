require "test_helper"

class EmployeeDocumentTest < ActiveSupport::TestCase
  setup do
    organization = Organization.create!(name: "Document Org", external_id: "doc_org")
    employer = organization.employers.create!(name: "Document Employer", status: "active")
    @employee = employer.employees.create!(first_name: "Taylor", last_name: "Reed", email: "taylor@example.com")
  end

  test "requested and pending documents need attention" do
    requested = @employee.employee_documents.create!(title: "Form I-9", document_type: "identity", status: "requested")
    pending = @employee.employee_documents.create!(title: "Benefits disclosure", document_type: "benefits", status: "pending")

    assert requested.requested?
    assert requested.attention_needed?
    assert pending.pending?
    assert pending.attention_needed?
  end

  test "complete documents can still need renewal attention" do
    expiring = @employee.employee_documents.create!(title: "Handbook acknowledgment", document_type: "policy", status: "complete", expires_on: Date.current + 10.days)

    assert expiring.complete?
    assert expiring.expiring_soon?
    assert expiring.attention_needed?
  end

  test "expired document detection uses expiry date" do
    document = @employee.employee_documents.create!(title: "Benefits disclosure", document_type: "benefits", status: "complete", expires_on: Date.current - 1.day)

    assert document.expired?
    assert document.attention_needed?
  end
end
