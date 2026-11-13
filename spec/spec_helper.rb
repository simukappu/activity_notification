ENV["RAILS_ENV"] ||= "test"
Warning[:deprecated] = true if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new("2.7.2")

require 'bundler/setup'
Bundler.setup

require 'simplecov'
require 'simplecov-lcov'
require 'rails'
# Write an LCOV report for the Coveralls GitHub Action. It respects :nocov: blocks, unlike .resultset.json
SimpleCov::Formatter::LcovFormatter.config do |config|
  config.report_with_single_file = true
  config.single_report_path = 'coverage/lcov.info'
end
SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new [
  SimpleCov::Formatter::HTMLFormatter,
  SimpleCov::Formatter::LcovFormatter
]
SimpleCov.start('rails') do
  # Fail CI builds when line coverage of each job drops below 100%
  minimum_coverage 100 if ENV['CI']
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
    if ActivityNotification.config.orm == :dynamoid && model_class.include?(Dynamoid::Document)
      # Truncate tables instead of deleting and re-creating them since table deletion takes seconds on DynamoDB and AWS Emulator
      model_class.create_table(sync: true)
      Dynamoid.adapter.truncate(model_class.table_name)
    else
      model_class.delete_all
    end
  end
end

RSpec.configure do |config|
  config.expect_with  :minitest, :rspec
  config.include FactoryBot::Syntax::Methods
  config.before(:each) do
    FactoryBot.reload
    clean_database
  end
  config.include Devise::Test::ControllerHelpers, type: :controller
end
