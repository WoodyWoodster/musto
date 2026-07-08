module Vitable
  DemoCertificationResultDto = Data.define(
    :environment,
    :base_url,
    :checked_at,
    :sdk_version,
    :certification_id,
    :public_webhook_url,
    :cases,
    :counts,
    :remote_ids,
    :artifact_paths
  ) do
    def certified?
      cases.all? { |entry| entry.fetch("status") == "passed" }
    end

    def to_h
      {
        "certification_id" => certification_id,
        "environment" => environment,
        "base_url" => base_url,
        "checked_at" => checked_at.iso8601,
        "sdk_version" => sdk_version,
        "public_webhook_url" => public_webhook_url,
        "status" => certified? ? "certified" : "failed",
        "counts" => counts,
        "remote_ids" => remote_ids,
        "artifact_paths" => artifact_paths,
        "cases" => cases
      }.compact
    end

    def to_markdown
      lines = [
        "# Vitable Demo Certification",
        "",
        "- Certification ID: `#{certification_id}`",
        "- Environment: `#{environment}`",
        "- Base URL: `#{base_url}`",
        "- Checked at: `#{checked_at.iso8601}`",
        "- SDK version: `#{sdk_version}`",
        "- Status: `#{certified? ? "certified" : "failed"}`",
        "",
        "| Status | Method | Operation | Endpoint | Remote IDs | Request logs |",
        "| --- | --- | --- | --- | --- | --- |"
      ]

      cases.each do |entry|
        lines << [
          entry.fetch("status"),
          entry.fetch("method"),
          "`#{entry.fetch("operation")}`",
          "`#{entry.fetch("endpoint")}`",
          inline_json(entry.fetch("remote_ids", {})),
          Array(entry.fetch("request_log_ids", [])).join(", ").presence || "-"
        ].join(" | ").prepend("| ").concat(" |")
      end

      failed = cases.select { |entry| entry.fetch("status") != "passed" }
      if failed.any?
        lines.concat([ "", "## Failures" ])
        failed.each do |entry|
          lines << "- `#{entry.fetch("operation")}`: #{entry.fetch("error", "Certification case did not pass")}"
        end
      end

      lines.join("\n")
    end

    private

    def inline_json(value)
      return "-" if value.blank?

      "`#{JSON.generate(value)}`"
    end
  end
end
