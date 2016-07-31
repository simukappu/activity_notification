require 'rails'
require 'active_support'
require 'action_view'

module ActivityNotification
  extend ActiveSupport::Concern
  extend ActiveSupport::Autoload

  autoload :Notification,     'activity_notification/models/notification'
  autoload :Target,           'activity_notification/models/target'
  autoload :Notifiable,       'activity_notification/models/notifiable'
  autoload :ActsAsTarget,     'activity_notification/roles/acts_as_target'
  autoload :ActsAsNotifiable, 'activity_notification/roles/acts_as_notifiable'
  autoload :StoreController,  'activity_notification/controllers/store_controller'
  autoload :NotificationApi,  'activity_notification/apis/notification_api'
  autoload :Common
  autoload :Config
  autoload :Renderable
  autoload :VERSION


  module Mailers
    autoload :Helpers,        'activity_notification/mailers/helpers'
  end

  # Returns ActivityNotification's configuration object.
  def self.config
    @config ||= ActivityNotification::Config.new
  end

  # Lets you set global configuration options.
  #
  # All available options and their defaults are in the example below:
  # @example Initializer for Rails
  #   ActivityNotification.configure do |config|
  #     config.enabled       = false
  #     config.table_name    = "notifications"
  #     ...
  #   end
  def self.configure(&block)
    yield(config) if block_given?
  end

end

# Load ActivityNotification helpers
require 'activity_notification/helpers/polymorphic_helpers'
require 'activity_notification/helpers/view_helpers'

# Define Rails::Engine
require 'activity_notification/rails'

