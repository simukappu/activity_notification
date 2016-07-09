require 'rails/generators/active_record'

module ActivityNotification
  module Generators
    # Notification generator that creates notification model file from template
    class NotificationGenerator < ActiveRecord::Generators::Base
      source_root File.expand_path("../../../templates/notification", __FILE__)

      argument :name, type: :string, default: 'notification'

      # Create model in project's folder
      def generate_files
        copy_file 'notification.rb', "app/models/#{name}.rb"
      end
    end
  end
end
