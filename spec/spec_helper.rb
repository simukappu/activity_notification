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
  add_filter '/lib/activity_notification/version'
  if ENV['AN_ORM'] == 'mongoid'
    add_filter '/lib/activity_notification/orm/active_record'
    add_filter '/lib/activity_notification/orm/dynamoid'
  elsif ENV['AN_ORM'] == 'dynamoid'
    add_filter '/lib/activity_notification/orm/active_record'
    add_filter '/lib/activity_notification/orm/mongoid'
  else
    add_filter '/lib/activity_notification/orm/mongoid'
    add_filter '/lib/activity_notification/orm/dynamoid'
  end
  if Rails::VERSION::MAJOR < 5
    add_filter '/app/channels/'
    add_filter '/lib/activity_notification/optional_targets/action_cable_channel'
    add_filter '/lib/activity_notification/optional_targets/action_cable_api_channel'
  end
end

# Dummy application
require 'rails_app/config/environment'

require 'rspec/rails'
require 'ammeter/init'
require "action_cable/testing/rspec" if Rails::VERSION::MAJOR == 5
require 'factory_bot_rails'
require 'activity_notification'

Dir[Rails.root.join("../../spec/support/**/*.rb")].each { |file| require file }

def clean_database
  [ActivityNotification::Notification, ActivityNotification::Subscription, Comment, Article, Admin, User].each do |model_class|
    model_class.delete_all
  end
end

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods
  config.before(:each) do
    FactoryBot.reload
    clean_database
  end
  config.include Devise::Test::ControllerHelpers, type: :controller
end
