require 'rails/generators/active_record'

module ActivityNotification
  module Generators
    # Notification generator that creates notification model file from template
    class NotificationGenerator < ActiveRecord::Generators::Base
      source_root File.expand_path("../../../templates/notification", __FILE__)

      argument :name, type: :string, default: 'Notification'

      # Create model in application directory
      def create_models
        @model_name = name
        template 'notification.rb', "app/models/#{name.underscore}.rb"
      end
    end
  end
end
