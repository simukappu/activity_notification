require 'rails/generators/active_record'

module ActivityNotification
  module Generators
    # Migration generator that creates migration file from template
    class MigrationGenerator < ActiveRecord::Generators::Base
      source_root File.expand_path("../../../templates/active_record", __FILE__)

      argument :name, type: :string, default: 'create_notifications'

      # Create migration in project's folder
      def generate_files
        migration_template 'migration.rb', "db/migrate/#{name}.rb"
      end
    end
  end
end
