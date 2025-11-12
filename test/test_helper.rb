# encoding: utf-8
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

Warden.test_mode!

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)

    fixtures :all
  end
end

class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  teardown do
    Warden.test_reset!
  end
end
