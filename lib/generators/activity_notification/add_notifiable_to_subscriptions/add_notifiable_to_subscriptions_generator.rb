require 'rails/generators/active_record'

module ActivityNotification
  module Generators
    # Migration generator to add notifiable columns to subscriptions table
    # for instance-level subscription support.
    # @example Run migration generator
    #   rails generate activity_notification:add_notifiable_to_subscriptions
    class AddNotifiableToSubscriptionsGenerator < ActiveRecord::Generators::Base
      source_root File.expand_path("templates", __dir__)

      argument :name, type: :string, default: 'AddNotifiableToSubscriptions',
        desc: "The migration name"

      # Create migration file in application directory
      def create_migration_file
        @migration_name = name
        migration_template 'add_notifiable_to_subscriptions.rb',
                           "db/migrate/#{name.underscore}.rb"
      end
    end
  end
end
