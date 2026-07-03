module Scheduling
  CenterDto = Data.define(:employer, :metrics, :shifts, :swap_requests, :issues, :forecasts, :forecast_lines, :forecast_holdbacks, :forecast_payload) do
    def latest_forecast
      forecasts.first
    end

    def publishable_shifts
      shifts.select(&:publishable?)
    end

    def open_shifts
      shifts.select(&:open_shift?)
    end

    def reviewable_swaps
      swap_requests.select(&:reviewable?)
    end
  end
end
