source 'https://rubygems.org'

gemspec

gem 'rails', '~> 8.1.0'

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
end

gem 'ostruct'
gem 'webpacker', groups: [:production, :development]
gem 'rack-cors', groups: [:production, :development]
gem 'dotenv-rails', groups: [:development, :test]
