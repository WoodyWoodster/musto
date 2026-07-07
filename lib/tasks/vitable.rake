require "json"

namespace :vitable do
  desc "Run a read-only smoke check against the configured Vitable demo API"
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
end
