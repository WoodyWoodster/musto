module YearEnd
  class TaxFormsQuery
    def initialize(employer_repository: Employers::EmployerRepository.new, tax_year: Date.current.year)
      @employer = employer_repository.first_for_operations
      @repository = TaxFormRepository.new(employer: @employer, tax_year:)
    end

    def call
      form_records = @repository.forms.to_a
      issues = @repository.issues
      packet_payload = @repository.latest_packet

      CenterDto.new(
        employer: Operations::EmployerContextDto.from_record(@employer),
        tax_year: @repository.tax_year,
        metrics: metrics(form_records, issues, packet_payload),
        forms: form_records.map { |form| TaxFormDto.from_record(form) },
        issues: issues.map { |issue| IssueDto.from_hash(issue) },
        packet: packet_payload.present? ? PacketDto.from_hash(packet_payload) : nil,
        packet_lines: packet_payload.to_h.fetch("forms", []).map { |line| PacketLineDto.from_hash(line) },
        packet_holdbacks: packet_payload.to_h.fetch("holdbacks", []).map { |issue| IssueDto.from_hash(issue) },
        packet_payload:
      )
    end

    private

    def metrics(forms, issues, packet_payload)
      w2_count = forms.count(&:employee_form?)
      contractor_count = forms.count(&:contractor_form?)
      deliverable_count = forms.count(&:deliverable?)
      correction_count = forms.count(&:correction_needed?)

      [
        MetricDto.new(label: "W-2 forms", value: w2_count, hint: "#{deliverable_count} total deliverable forms", status: w2_count.positive? ? "ready" : "needs_review", accent: "bg-indigo-500", format: "number"),
        MetricDto.new(label: "1099 forms", value: contractor_count, hint: "contractor tax forms", status: contractor_count.positive? ? "ready" : "needs_review", accent: "bg-cyan-500", format: "number"),
        MetricDto.new(label: "Holdbacks", value: issues.count, hint: "#{correction_count} corrections flagged", status: issues.any? ? "needs_review" : "ready", accent: "bg-rose-500", format: "number"),
        MetricDto.new(label: "Packet", value: packet_payload.to_h.fetch("status", "Not generated").humanize, hint: "#{@repository.tax_year} year-end filing packet", status: packet_payload.to_h.fetch("status", "pending"), accent: "bg-emerald-500", format: "text")
      ]
    end
  end
end
