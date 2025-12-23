source 'https://rubygems.org'

gemspec

gem 'rails', '~> 8.0.0'

group :production do
  gem 'sprockets-rails'
  gem 'puma'
  gem 'pg'
  gem 'devise'
  gem 'devise_token_auth'
end

group :development do
  gem 'bullet'
end

group :test do
  gem 'rails-controller-testing'
  gem 'ammeter'
  gem 'timecop'
  gem 'committee'
  gem 'committee-rails', '< 0.6'
  # gem 'coveralls', require: false
  gem 'coveralls_reborn', require: false
  # Optional ORM dependencies for testing
  gem 'mongoid', '>= 4.0.0', '< 10.0'
  gem 'dynamoid', '>= 3.11.0', '< 4.0'
end

gem 'webpacker', groups: [:production, :development]
gem 'rack-cors', groups: [:production, :development]
gem 'dotenv-rails', groups: [:development, :test]
