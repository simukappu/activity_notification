require 'rails/generators/base'

module ActivityNotification
  module Generators
    # View generator to copy customizable view files to rails application.
    # Include this module in your generator to generate ActivityNotification views.
    # `copy_views` is the main method and by default copies all views of ActivityNotification.
    class ViewsGenerator < Rails::Generators::Base
      VIEWS = [:notifications, :mailer].freeze

      source_root File.expand_path("../../../../app/views/activity_notification", __FILE__)
      desc "Copies default ActivityNotification views to your application."

      argument :target, required: false, default: nil,
        desc: "The target to copy views to"
      class_option :views, aliases: "-v", type: :array,
        desc: "Select specific view directories to generate (notifications, mailer)"
      public_task :copy_views

      # Copies view files in application directory
      def copy_views
        target_views = options[:views] || VIEWS
        target_views.each do |directory|
          view_directory directory.to_sym
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
