class ApplicationRepository
  private

  def vitable_connection_for(organization)
    connections = organization&.integration_connections&.vitable
    return unless connections

    connections.find_by(environment: preferred_vitable_environment) ||
      connections.find_by(environment: "demo")
  end

  def preferred_vitable_environment
    Vitable::Configuration.default_environment
  end

  def severity_sort
    Arel.sql("CASE severity WHEN 'critical' THEN 0 WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END")
  end
end
