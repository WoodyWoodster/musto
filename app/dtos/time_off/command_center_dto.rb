module TimeOff
  CommandCenterDto = Data.define(:employer, :metrics, :policies, :balances, :requests, :calendar_blocks) do
    def pending_requests
      requests.select(&:requested?)
    end

    def approved_requests
      requests.select(&:approved?)
    end

    def risk_balances
      balances.select(&:needs_attention?)
    end
  end
end
