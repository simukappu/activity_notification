# Load the Rails application.
require File.expand_path('../application', __FILE__)

# Initialize the Rails application.
Rails.application.initialize!

# Load database schema
if Rails.env.test?
  silence_stream(STDOUT) do
    load "#{Rails.root}/db/schema.rb"
  end
end