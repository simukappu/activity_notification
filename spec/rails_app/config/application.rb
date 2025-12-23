require File.expand_path('../boot', __FILE__)

# Load mongoid configuration if necessary:
if ENV['AN_ORM'] == 'mongoid'
  begin
    require 'mongoid'
    require 'rails'
    unless Rails.env.test?
      Mongoid.load!(File.expand_path("config/mongoid.yml"), :development)
    end
  rescue LoadError => e
    raise LoadError, "Cannot load mongoid gem. Please ensure 'mongoid' is in your Gemfile when using AN_ORM=mongoid. Error: #{e.message}"
  end
# Load dynamoid configuration if necessary:
elsif ENV['AN_ORM'] == 'dynamoid'
  begin
    require 'dynamoid'
    require 'rails'
    require File.expand_path('../dynamoid', __FILE__)
  rescue LoadError => e
    raise LoadError, "Cannot load dynamoid gem. Please ensure 'dynamoid' is in your Gemfile when using AN_ORM=dynamoid. Error: #{e.message}"
  end
end

# Pick the frameworks you want:
if ENV['AN_ORM'] == 'mongoid' && ENV['AN_TEST_DB'] == 'mongodb'
  require "mongoid/railtie"
else
  require "active_record/railtie"
end
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_view/railtie"
require "sprockets/railtie"
require 'action_cable/engine'

Bundler.require(*Rails.groups)
require "activity_notification"

module Dummy
  class Application < Rails::Application
    if Gem::Version.new("5.2.0") <= Rails.gem_version && Rails.gem_version < Gem::Version.new("6.0.0") && ENV['AN_TEST_DB'] != 'mongodb'
      config.active_record.sqlite3.represent_boolean_as_integer = true
    end
    config.active_support.to_time_preserves_timezone = :zone

    # Configure CORS for API mode
    if defined?(Rack::Cors)
      config.middleware.insert_before 0, Rack::Cors do
        allow do
          origins '*'
          resource '*',
            headers: :any,
            expose: ['access-token', 'client', 'uid'],
            methods: [:get, :post, :put, :delete]
        end
      end
    end
  end
end

puts "ActivityNotification test parameters: AN_ORM=#{ENV['AN_ORM'] || 'active_record(default)'} AN_TEST_DB=#{ENV['AN_TEST_DB'] || 'sqlite(default)'}"
