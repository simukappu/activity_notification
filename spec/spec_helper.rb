ENV["RAILS_ENV"] ||= "test"

require 'bundler/setup'
Bundler.setup

if ENV['COV']
  require 'simplecov'
  SimpleCov.start do
    add_filter '/spec/'
  end
elsif ENV["TRAVIS"]
  require 'coveralls'
  Coveralls.wear!
end

# Dummy application
require 'devise'
require 'rails_app/config/environment'

#require 'rails'
#require 'rspec-rails'
require 'activity_notification'
require 'factory_girl_rails'

# For active record ORM
require 'active_record'

RSpec.configure do |config|
  config.include FactoryGirl::Syntax::Methods
  config.before(:all) do
    FactoryGirl.reload
  end
end