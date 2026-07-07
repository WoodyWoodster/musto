module Benefits
  PlanAdministrationCenterDto = Data.define(
    :employer,
    :connection_id,
    :connection_status,
    :credentials_present,
    :api_key_reference,
    :metrics,
    :plans,
    :issues,
    :packet,
    :packet_lines,
    :packet_holdbacks,
    :remote_snapshot,
    :mapped_plans,
    :mapping_issues,
    :mapping_runs,
    :request_logs
  )
end
