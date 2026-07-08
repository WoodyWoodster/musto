ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "support/vitable_env_helper"

module ActiveSupport
  class TestCase
    include VitableEnvHelper

    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    teardown { clear_vitable_env }

    # Add more helper methods to be used by all tests here...
  end
end
