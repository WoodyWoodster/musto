require "test_helper"

module Vitable
  class RemotePayrollDeductionDtoTest < ActiveSupport::TestCase
    test "normalizes nested payroll deduction responses" do
      dto = RemotePayrollDeductionDto.from_hash(
        "data" => {
          "payroll_deduction" => {
            "deduction_id" => "pded_remote_primary",
            "benefit" => {
              "id" => "bprd_primary",
              "name" => "Primary Care",
              "category" => "Medical"
            },
            "deduction_amount_in_cents" => 7_900,
            "frequency" => "bi_weekly",
            "period_start_on" => "2026-07-01",
            "period_end_on" => "2026-07-31",
            "tax_treatment" => "Pre-tax",
            "deduction_status" => "active"
          }
        }
      )

      assert_equal "pded_remote_primary", dto.remote_id
      assert_equal "Primary Care", dto.benefit_name
      assert_equal "Medical", dto.category
      assert_equal 7_900, dto.amount_cents
      assert_equal "bi_weekly", dto.frequency
      assert_equal Date.new(2026, 7, 1), dto.period_start_on
      assert_equal Date.new(2026, 7, 31), dto.period_end_on
      assert_equal "Pre-tax", dto.tax_classification
      assert_equal "active", dto.remote_status
      assert_equal "VITABLE_PRIMARY_CARE", dto.payroll_code
      assert_equal "pded_remote_primary", dto.raw_payload.fetch("id")
      assert_equal 7_900, dto.raw_payload.fetch("deduction_amount_in_cents")
      assert_equal "2026-07-01", dto.raw_payload.fetch("period_start_date")
      assert_equal "2026-07-31", dto.raw_payload.fetch("period_end_date")
    end

    test "preserves employee context around nested deduction envelopes" do
      dto = RemotePayrollDeductionDto.from_hash(
        "data" => {
          "employee" => {
            "id" => "empl_remote_123",
            "email" => "casey@example.com"
          },
          "payroll_deduction" => {
            "id" => "pded_remote_context",
            "benefit_name" => "Primary Care",
            "amount_cents" => 5_500,
            "status" => "active"
          }
        }
      )

      assert_equal "pded_remote_context", dto.remote_id
      assert_equal "Primary Care", dto.benefit_name
      assert_equal 5_500, dto.amount_cents
      assert_equal "empl_remote_123", dto.raw_payload.dig("employee", "id")
      assert_equal "casey@example.com", dto.raw_payload.dig("employee", "email")
    end

    test "falls back to enrollment benefit data for deduction naming" do
      dto = RemotePayrollDeductionDto.from_hash(
        "deduction" => {
          "payroll_deduction_id" => "pded_remote_dental",
          "amount_in_cents" => "3200",
          "enrollment" => {
            "benefit" => {
              "name" => "Dental Plus",
              "category" => "Dental"
            }
          },
          "status" => "pending"
        }
      )

      assert_equal "pded_remote_dental", dto.remote_id
      assert_equal "Dental Plus", dto.benefit_name
      assert_equal "Dental", dto.category
      assert_equal 3_200, dto.amount_cents
      assert_equal "waiting_on_enrollment", dto.payroll_status
      assert_equal "VITABLE_DENTAL_PLUS", dto.payroll_code
    end
  end
end
