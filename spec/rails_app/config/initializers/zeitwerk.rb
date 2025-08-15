# Mongoid 9.0+ compatibility
if ENV['AN_ORM'] == 'mongoid'
  # Preload helper modules before Rails initialization
  Rails.application.config.before_initialize do
    # Load all helper files manually to avoid Zeitwerk issues
    Dir[Rails.root.join('app', 'helpers', '*.rb')].each do |helper_file|
      require_dependency helper_file
    end
  end
end