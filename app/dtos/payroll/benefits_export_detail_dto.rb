module Payroll
  BenefitsExportDetailDto = Data.define(
    :payroll_run,
    :employer_name,
    :organization_name,
    :batch,
    :metrics,
    :preflight_checks,
    :lines,
    :included_lines,
    :holdback_lines,
    :payload
  ) do
    def self.from_record(record)
      lines = record.payroll_deductions.sort_by(&:created_at).reverse.map { |deduction| BenefitsExportLineDto.from_record(deduction) }
      included_lines = lines.select(&:included?)
      holdback_lines = lines.reject(&:included?)
      batch = (record.metadata || {}).fetch("benefits_export", {})

      new(
        payroll_run: Operations::PayrollRunDto.from_record(record),
        employer_name: record.employer.name,
        organization_name: record.employer.organization.name,
        batch:,
        metrics: metrics(lines, included_lines, holdback_lines),
        preflight_checks: preflight_checks(record, included_lines, holdback_lines, batch),
        lines:,
        included_lines:,
        holdback_lines:,
        payload: batch.presence || preview_payload(record, included_lines, holdback_lines)
      )
    end

    def generated?
      batch.present?
    end

    def batch_id
      batch.fetch("batch_id", "Not generated")
    end

    def generated_at
      value = batch["generated_at"]
      value.present? ? Time.iso8601(value) : nil
    end

    def self.metrics(lines, included_lines, holdback_lines)
      [
        BenefitsExportMetricDto.new(label: "Export lines", value: included_lines.count, status: included_lines.any? ? "ready" : "needs_review"),
        BenefitsExportMetricDto.new(label: "Holdbacks", value: holdback_lines.count, status: holdback_lines.any? ? "needs_review" : "ready"),
        BenefitsExportMetricDto.new(label: "Export total", value: included_lines.sum(&:amount_cents), status: included_lines.any? ? "ready" : "needs_review"),
        BenefitsExportMetricDto.new(label: "Reviewed deductions", value: lines.count, status: lines.any? ? "ready" : "needs_review")
      ]
    end

    def self.preflight_checks(record, included_lines, holdback_lines, batch)
      [
        BenefitsExportPreflightCheckDto.new(
          label: "Payroll run state",
          status: record.status == "finalized" ? "finalized" : "needs_review",
          detail: record.status == "finalized" ? "Run is locked" : "Run is still #{record.status.humanize.downcase}; export is marked as reviewable"
        ),
        BenefitsExportPreflightCheckDto.new(
          label: "Exportable deductions",
          status: included_lines.any? ? "ready" : "needs_review",
          detail: "#{included_lines.count} deductions will be included"
        ),
        BenefitsExportPreflightCheckDto.new(
          label: "Holdback review",
          status: holdback_lines.any? ? "needs_review" : "ready",
          detail: holdback_lines.any? ? "#{holdback_lines.count} deductions held back" : "No holdbacks"
        ),
        BenefitsExportPreflightCheckDto.new(
          label: "Manifest",
          status: batch.present? ? "ready" : "pending",
          detail: batch.present? ? "Batch #{batch.fetch("batch_id")} generated" : "Generate a manifest to persist the export package"
        )
      ]
    end

    def self.preview_payload(record, included_lines, holdback_lines)
      {
        payroll_run_id: record.id,
        status: "preview",
        line_count: included_lines.count,
        holdback_count: holdback_lines.count,
        total_cents: included_lines.sum(&:amount_cents)
      }
    end

    private_class_method :metrics, :preflight_checks, :preview_payload
  end
end
