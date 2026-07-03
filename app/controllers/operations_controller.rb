class OperationsController < ApplicationController
  def workforce
    @workforce = Operations::WorkforceQuery.new.call
  end

  def payroll
    @payroll = Operations::PayrollQuery.new.call
  end

  def benefits
    @benefits = Operations::BenefitsQuery.new.call
  end

  def compliance
    @compliance = Operations::ComplianceQuery.new.call
  end

  def integrations
    @integrations = Operations::IntegrationsQuery.new.call
  end
end
