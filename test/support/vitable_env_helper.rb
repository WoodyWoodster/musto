module VitableEnvHelper
  def clear_vitable_env(*keys)
    target_keys = keys.flatten.compact.presence || ENV.keys.grep(/\AVITABLE_/)
    target_keys.each { |key| ENV.delete(key.to_s) }
  end

  def set_vitable_env(overrides)
    overrides.each do |key, value|
      value.nil? ? ENV.delete(key.to_s) : ENV[key.to_s] = value
    end
  end

  def with_vitable_env(overrides)
    previous = overrides.keys.index_with { |key| ENV.fetch(key.to_s, nil) }
    previous_presence = overrides.keys.index_with { |key| ENV.key?(key.to_s) }
    set_vitable_env(overrides)
    yield
  ensure
    previous.each do |key, value|
      previous_presence.fetch(key) ? ENV[key.to_s] = value : ENV.delete(key.to_s)
    end
  end
end
