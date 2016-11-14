require 'rails/generators/active_record'

module ActivityNotification
  module Generators
    # Notification generator to create customizable notification model from templates.
    # @example Run notification generator to create customizable notification model
    #   rails generate activity_notification:notification
    class NotificationGenerator < ActiveRecord::Generators::Base
      source_root File.expand_path("../../../templates/notification", __FILE__)

      argument :name, type: :string, default: 'Notification'

      # Create notification model in application directory
      def create_models
        @model_name = name
        template 'notification.rb', "app/models/#{name.underscore}.rb"
      end
    end
  end
end
