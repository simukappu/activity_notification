source 'https://rubygems.org'

gemspec

gem 'rails', '~> 5.1'

#TODO Remove it after devise supporting rails 5.1 is released
gem 'devise', github: 'plataformatec/devise', ref: '83002017'
gem 'mail', '~>2.6.6.rc1'

group :development do
  gem 'bullet'
end

group :test do
  gem 'rails-controller-testing'
  gem 'ammeter'
  gem 'timecop'
  gem 'coveralls', require: false
end

gem 'dotenv-rails', groups: [:development, :test]
