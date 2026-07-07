class ApplicationRepository
  private

  def vitable_connection_for(organization)
    connections = organization&.integration_connections&.vitable
    return unless connections

    connections.find_by(environment: preferred_vitable_environment) ||
      connections.find_by(environment: "demo") ||
      connections.find_by(environment: "production") ||
      connections.first
  end

  def preferred_vitable_environment
    ENV.fetch("VITABLE_CONNECT_ENVIRONMENT", "demo").presence || "demo"
  end

  def severity_sort
    Arel.sql("CASE severity WHEN 'critical' THEN 0 WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END")
  end
end
