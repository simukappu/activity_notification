# Load the Rails application.
require File.expand_path('../application', __FILE__)

# Initialize the Rails application.
Rails.application.initialize!

def silent_stdout(&block)
  original_stdout = $stdout
  $stdout = fake = StringIO.new
  begin
    yield
  ensure
    $stdout = original_stdout
  end
end

# Load database schema
if Rails.env.test? && ENV['AN_TEST_DB'] != 'mongodb'
  silent_stdout do
    load "#{Rails.root}/db/schema.rb"
  end
end
