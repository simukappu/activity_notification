ENV["RAILS_ENV"] ||= "test"

require 'bundler/setup'
Bundler.setup

require 'simplecov'
require 'coveralls'
require 'rails'
Coveralls.wear!
SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new [
  SimpleCov::Formatter::HTMLFormatter,
  Coveralls::SimpleCov::Formatter
]
SimpleCov.start('rails') do
  add_filter '/spec/'
  add_filter '/lib/generators/templates/'
  add_filter '/lib/activity_notification/version.rb'
  if Rails::VERSION::MAJOR == 5
    nocov_token 'skip-rails5'
  elsif Rails::VERSION::MAJOR == 4
    nocov_token 'skip-rails4'
  end
  if ENV['AN_ORM'] == 'mongoid'
    add_filter '/lib/activity_notification/orm/active_record'
  else
    add_filter '/lib/activity_notification/orm/mongoid'
  end
end

# Testing with Devise
require 'devise'
# Dummy application
require 'rails_app/config/environment'

require 'rspec/rails'
require 'ammeter/init'
require 'factory_girl_rails'
require 'activity_notification'

# For active record ORM
require 'active_record'

RSpec.configure do |config|
  config.include FactoryGirl::Syntax::Methods
  config.before(:all) do
    FactoryGirl.reload
    ActivityNotification::Notification.delete_all
    ActivityNotification::Subscription.delete_all
  end
  config.include Devise::Test::ControllerHelpers, type: :controller
end