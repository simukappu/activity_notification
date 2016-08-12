ENV["RAILS_ENV"] ||= "test"

require 'bundler/setup'
Bundler.setup

require 'simplecov'
require 'coveralls'
SimpleCov.formatter = Coveralls::SimpleCov::Formatter
SimpleCov.start do
  add_filter '/spec/'
end
#Coveralls.wear!

# Dummy application
require 'devise'
require 'rails_app/config/environment'

require 'rspec/rails'
require 'factory_girl_rails'
require 'activity_notification'

# For active record ORM
require 'active_record'

RSpec.configure do |config|
  config.include FactoryGirl::Syntax::Methods
  config.before(:all) do
    FactoryGirl.reload
  end
end