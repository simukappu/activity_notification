source 'https://rubygems.org'

gemspec

gem 'rails', '~> 8.0.0'

group :production do
  gem 'sprockets-rails'
  gem 'puma'
  gem 'pg'
  gem 'devise'
  # https://github.com/lynndylanhurley/devise_token_auth/pull/1639
  gem 'devise_token_auth', git: 'https://github.com/lynndylanhurley/devise_token_auth.git'
  gem 'sqlite3', ">= 2.1"
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

gem 'webpacker', groups: [:production, :development]
gem 'rack-cors', groups: [:production, :development]
gem 'dotenv-rails', groups: [:development, :test]
