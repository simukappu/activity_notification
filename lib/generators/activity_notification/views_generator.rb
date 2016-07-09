require 'rails/generators/base'

module ActivityNotification
  module Generators
    # Include this module in your generator to generate ActivityNotification views.
    # `copy_views` is the main method and by default copies all views
    # with forms.
    class ViewsGenerator < Rails::Generators::Base
      source_root File.expand_path("../../../../app/views/activity_notification", __FILE__)
      desc "Copies default ActivityNotification views to your application."

      argument :target, required: false, default: nil,
                       desc: "The target to copy views to"
      class_option :views, aliases: "-v", type: :array, desc: "Select specific view directories to generate (notifications, mailer)"
      public_task :copy_views

      def copy_views
        if options[:views]
          options[:views].each do |directory|
            view_directory directory.to_sym
          end
        else
          view_directory :notifications
          view_directory :mailer
        end
      end

      protected

      def view_directory(name, _target_path = nil)
        directory "#{name.to_s}/default", _target_path || "#{target_path}/#{name}/#{plural_target || :default}"
      end

      def target_path
        @target_path ||= "app/views/activity_notification"
      end

      def plural_target
        @plural_target ||= target.presence && target.to_s.underscore.pluralize
      end
    end

  end
end
