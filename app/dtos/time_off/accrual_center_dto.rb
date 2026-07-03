module TimeOff
  AccrualCenterDto = Data.define(:employer, :metrics, :balances, :accruals, :issues, :packet, :packet_lines, :packet_holdbacks) do
    def pending_accruals
      accruals.select(&:pending?)
    end

    def risk_balances
      balances.select(&:needs_attention?)
    end
  end
end
