module TimeOff
  class TimeOffRepository < ApplicationRepository
    def initialize(employer: nil)
      @employer = employer
    end

    def policies
      return TimeOffPolicy.none unless @employer

      @employer.time_off_policies.includes(:time_off_requests).order(:name)
    end

    def active_policies
      policies.active
    end

    def employees
      return Employee.none unless @employer

      @employer.employees.active.includes(:department, :work_location, time_off_requests: [ :time_off_policy ]).order(:last_name, :first_name)
    end

    def requests
      return TimeOffRequest.none unless @employer

      TimeOffRequest
        .joins(:employee)
        .where(employees: { employer_id: @employer.id })
        .includes(:time_off_policy, employee: [ :department, :work_location ])
        .order(:starts_on, :ends_on)
    end

    def upcoming_requests
      requests.upcoming
    end

    def find_time_off_request(id)
      TimeOffRequest.includes(:employee, :time_off_policy).find(id)
    end

    def review_time_off_request(request, decision)
      request.update!(
        status: decision,
        reviewed_at: Time.current,
        metadata: review_metadata(request, decision)
      )
      request
    end

    private

    def review_metadata(request, decision)
      request.metadata.to_h.merge(
        "reviewed_from" => "time_off_command_center",
        "review_decision" => decision,
        "reviewed_at" => Time.current.iso8601
      )
    end
  end
end
