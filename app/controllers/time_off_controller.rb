class TimeOffController < ApplicationController
  def show
    @time_off = TimeOff::CommandCenterQuery.new.call
  end
end
