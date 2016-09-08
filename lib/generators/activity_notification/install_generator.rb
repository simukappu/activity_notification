require 'rails/generators/base'
require 'securerandom'

module ActivityNotification
  module Generators #:nodoc:
    # Install generator to copy initializer and locale file to rails application.
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("../../templates", __FILE__)

      desc "Creates a ActivityNotification initializer and copy locale files to your application."
      class_option :orm

      # Copies initializer file in application directory
      def copy_initializer
        #TODO suport other orm e.g. mongoid
        unless options[:orm] == :active_record
          raise TypeError, <<-ERROR.strip_heredoc
          Currently ActivityNotification is only supported with Active Record ORM.

          Be sure to have an Active Record ORM loaded in your
          app or configure your own at `config/application.rb`.

            config.generators do |g|
              g.orm :active_record
            end
          ERROR
        end

        template "activity_notification.rb", "config/initializers/activity_notification.rb"
      end

      # Copies locale files in application directory
      def copy_locale
        template "locales/en.yml", "config/locales/activity_notification.en.yml"
      end

      # Shows readme to console
      def show_readme
        readme "README" if behavior == :invoke
      end

    end
  end
end
