source 'https://rubygems.org'

gemspec

gem 'rails', '~> 6.0.0'

group :production do
  gem 'puma'
  gem 'pg'
  gem 'devise'
  gem 'devise_token_auth'
end

group :development do
  gem 'bullet'
end

group :test do
  #TODO https://github.com/rails/rails/issues/35417
  gem 'rspec-rails', '4.0.0.beta4'
  gem 'rails-controller-testing'
  gem 'ammeter'
  gem 'timecop'
  gem 'committee'
  gem 'committee-rails'
  gem 'coveralls', require: false
end

gem 'webpacker', groups: [:production, :development]
gem 'rack-cors', groups: [:production, :development]
gem 'dotenv-rails', groups: [:development, :test]
