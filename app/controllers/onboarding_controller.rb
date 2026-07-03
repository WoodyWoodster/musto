class OnboardingController < ApplicationController
  def show
    @onboarding = Onboarding::CommandCenterQuery.new.call
  end
end
