require "bundler/gem_tasks"

task default: :test

require 'rspec/core'
require 'rspec/core/rake_task'
desc 'Run RSpec test for the activity_notification plugin.'
RSpec::Core::RakeTask.new(:test) do |spec|
  spec.pattern = FileList['spec/**/*_spec.rb']
end

require 'yard'
require 'yard/rake/yardoc_task'
desc 'Generate documentation for the activity_notification plugin.'
YARD::Rake::YardocTask.new do |doc|
  doc.files = ['app/**/*.rb', 'lib/**/*.rb']
end

Bundler::GemHelper.install_tasks
