require "json"

namespace :vitable do
  desc "Run a demo smoke check against the configured Vitable API"
  task demo_smoke: :environment do
    dto = Vitable::RunDemoSmokeCheckDto.from_env
    result = Vitable::RunDemoSmokeCheckCommand.new(dto:).call
    payload = {
      success: result.success?,
      sync_run_id: result.record&.id,
      status: result.record&.status,
      errors: result.errors,
      result: result.value.respond_to?(:to_h) ? result.value.to_h : result.value
    }.compact

    puts JSON.pretty_generate(payload)
    abort("Vitable demo smoke check failed") unless result.success?
  end

  desc "Run a full demo certification against the configured Vitable API"
  task demo_certification: :environment do
    dto = Vitable::RunDemoCertificationDto.from_env
    result = Vitable::RunDemoCertificationCommand.new(dto:).call
    payload = {
      success: result.success?,
      sync_run_id: result.record&.id,
      status: result.record&.status,
      errors: result.errors,
      artifact_paths: result.value&.artifact_paths,
      result: result.value.respond_to?(:to_h) ? result.value.to_h : result.value
    }.compact

    puts JSON.pretty_generate(payload)
    abort("Vitable demo certification failed") unless result.success?
  end

  desc "Run a live API-only demo certification against the configured Vitable API"
  task demo_api_certification: :environment do
    dto = Vitable::RunDemoCertificationDto.from_env(
      scope_override: "api",
      default_requested_by: "demo_api_certification"
    )
    result = Vitable::RunDemoCertificationCommand.new(dto:).call
    payload = {
      success: result.success?,
      sync_run_id: result.record&.id,
      status: result.record&.status,
      errors: result.errors,
      artifact_paths: result.value&.artifact_paths,
      result: result.value.respond_to?(:to_h) ? result.value.to_h : result.value
    }.compact

    puts JSON.pretty_generate(payload)
    abort("Vitable demo API certification failed") unless result.success?
  end
end
