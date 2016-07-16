ENV["RAILS_ENV"] ||= "test"

require 'bundler/setup'
Bundler.setup

#TODO set environment
#if ENV['COV']
  require 'simplecov'
  SimpleCov.start do
    add_filter '/spec/'
  end
#elsif ENV["TRAVIS"] # in Travis-CI
  require 'coveralls'
  Coveralls.wear!
#end

#require 'rails'
#require 'rspec-rails'
require 'activity_notification'
require "rails_app/config/environment"
require 'factory_girl_rails'
#require 'devise'

# For active record ORM
require 'active_record'

RSpec.configure do |config|
  config.include FactoryGirl::Syntax::Methods
  config.before(:all) do
    FactoryGirl.reload
  end
end