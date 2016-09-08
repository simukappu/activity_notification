require 'rails/generators/active_record'

module ActivityNotification
  module Generators
    # Migration generator to create migration files from templates.
    class MigrationGenerator < ActiveRecord::Generators::Base
      source_root File.expand_path("../../../templates/active_record", __FILE__)

      argument :name, type: :string, default: 'CreateNotifications'

      # Create migration files in application directory
      def create_migrations
        @migration_name = name
        migration_template 'migration.rb', "db/migrate/#{name.underscore}.rb"
      end
    end
  end
end
