module PayStatements
  class StatementRepository < ApplicationRepository
    def initialize(employer: nil)
      @employer = employer
    end

    def statements
      return PayStatement.none unless @employer

      PayStatement
        .joins(:payroll_run)
        .where(payroll_runs: { employer_id: @employer.id })
        .includes(:payroll_run, employee: [ :department, :work_location ])
        .order(pay_date: :desc, created_at: :desc)
    end

    def current_run
      return unless @employer

      @employer
        .payroll_runs
        .includes(
          employer: [ :organization ],
          payroll_deductions: [ :payroll_run, :employee, { enrollment: [ :benefit_plan ] } ],
          payroll_adjustments: [ :payroll_run, :employee ]
        )
        .order(pay_date: :desc)
        .first
    end

    def batches
      payload = @employer&.settings.to_h.fetch("pay_statement_batch", nil)
      payload.present? ? [ payload ] : []
    end

    def find_statement(id)
      PayStatement.includes(:payroll_run, employee: [ :department, :work_location ]).find(id)
    end

    def deliver_statement(statement, delivered_by:)
      statement.deliver!(delivered_by:)
    end

    def generate_batch(requested_by:)
      run = current_run
      return empty_batch(requested_by:) unless run

      payroll_detail = Payroll::RunDetailDto.from_record(run)
      lines, holdbacks = generate_statement_lines(run, payroll_detail)
      batch = batch_payload(run, lines, holdbacks, requested_by:)

      @employer.update!(settings: @employer.settings.to_h.merge("pay_statement_batch" => batch))
      batch
    end

    private

    def generate_statement_lines(run, payroll_detail)
      lines = []
      holdbacks = []

      payroll_detail.line_items.each do |line|
        if line.estimated_net_pay_cents <= 0
          holdbacks << holdback_line(line, reason: "Net pay must be positive before a pay statement can be delivered")
          next
        end

        statement = PayStatement.find_or_initialize_by(payroll_run: run, employee_id: line.employee_id)
        statement.assign_attributes(statement_attributes(run, line, statement))
        statement.save!
        lines << statement_line(statement)
      end

      [ lines, holdbacks ]
    end

    def statement_attributes(run, line, statement)
      {
        statement_number: statement.statement_number.presence || "PS-#{run.id}-#{line.employee_id}",
        period_start_on: run.period_start_on,
        period_end_on: run.period_end_on,
        pay_date: run.pay_date,
        gross_pay_cents: line.gross_pay_cents,
        adjustment_cents: line.adjustments_cents,
        deduction_cents: line.deductions_cents,
        tax_cents: line.estimated_tax_cents,
        net_pay_cents: line.estimated_net_pay_cents,
        status: statement.status.presence || "generated",
        delivery_method: statement.delivery_method.presence || "employee_portal",
        metadata: statement.metadata.to_h.merge(
          "generated_from" => "pay_statement_center",
          "generated_at" => Time.current.iso8601
        )
      }
    end

    def batch_payload(run, lines, holdbacks, requested_by:)
      {
        "batch_id" => "pay_statements_#{@employer.id}_#{run.id}_#{Time.current.to_i}",
        "generated_at" => Time.current.iso8601,
        "requested_by" => requested_by,
        "payroll_run_id" => run.id,
        "employer_id" => @employer.id,
        "pay_date" => run.pay_date.iso8601,
        "status" => lines.any? && holdbacks.empty? ? "ready" : "needs_review",
        "totals" => {
          "statement_count" => lines.count,
          "employee_count" => lines.map { |line| line.fetch("employee_id") }.uniq.count,
          "holdback_count" => holdbacks.count,
          "net_pay_cents" => lines.sum { |line| line.fetch("net_pay_cents") }
        },
        "statements" => lines,
        "holdbacks" => holdbacks
      }
    end

    def empty_batch(requested_by:)
      {
        "batch_id" => "pay_statements_#{@employer.id}_missing_run_#{Time.current.to_i}",
        "generated_at" => Time.current.iso8601,
        "requested_by" => requested_by,
        "payroll_run_id" => nil,
        "employer_id" => @employer.id,
        "pay_date" => Date.current.iso8601,
        "status" => "needs_review",
        "totals" => { "statement_count" => 0, "employee_count" => 0, "holdback_count" => 1, "net_pay_cents" => 0 },
        "statements" => [],
        "holdbacks" => [
          {
            "employee_id" => nil,
            "employee_name" => "Payroll run",
            "amount_cents" => 0,
            "reason" => "No current payroll run is available for statement generation",
            "status" => "needs_review"
          }
        ]
      }
    end

    def statement_line(statement)
      {
        "statement_id" => statement.id,
        "statement_number" => statement.statement_number,
        "employee_id" => statement.employee_id,
        "employee_name" => statement.employee.full_name,
        "gross_pay_cents" => statement.gross_pay_cents,
        "deduction_cents" => statement.deduction_cents,
        "tax_cents" => statement.tax_cents,
        "net_pay_cents" => statement.net_pay_cents,
        "status" => statement.status
      }
    end

    def holdback_line(line, reason:)
      {
        "employee_id" => line.employee_id,
        "employee_name" => line.employee_name,
        "amount_cents" => line.estimated_net_pay_cents,
        "reason" => reason,
        "status" => "needs_review"
      }
    end
  end
end
