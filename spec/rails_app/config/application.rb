require File.expand_path('../boot', __FILE__)

# Load mongoid configuration if necessary:
if ENV['AN_ORM'] == 'mongoid'
  require 'mongoid'
  require 'rails'
  if Rails.env != 'test'
    Mongoid.load!(File.expand_path("config/mongoid.yml"), :development)
  end
end

# Pick the frameworks you want:
unless ENV['AN_ORM'] == 'mongoid' && ENV['AN_TEST_DB'] == 'mongodb'
  require "active_record/railtie"
end
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_view/railtie"
require "sprockets/railtie"
# require "rails/test_unit/railtie"

Bundler.require(*Rails.groups)
require "activity_notification"

module Dummy
  class Application < Rails::Application
    # Do not swallow errors in after_commit/after_rollback callbacks.
    if Rails::VERSION::MAJOR == 4 && Rails::VERSION::MINOR >= 2 && ENV['AN_TEST_DB'] != 'mongodb'
      config.active_record.raise_in_transactional_callbacks = true
    end
  end
end

