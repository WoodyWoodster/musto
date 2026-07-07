module Vitable
  DemoSmokeCheckResultDto = Data.define(:environment, :base_url, :checked_at, :sdk_version, :checks, :counts, :samples, :warnings) do
    def to_h
      {
        "environment" => environment,
        "base_url" => base_url,
        "checked_at" => checked_at.iso8601,
        "sdk_version" => sdk_version,
        "checks" => checks,
        "counts" => counts,
        "samples" => samples,
        "warnings" => warnings
      }
    end
  end
end
