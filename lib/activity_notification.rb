require 'rails'
require 'active_support'
require 'action_view'

module ActivityNotification
  extend ActiveSupport::Concern
  extend ActiveSupport::Autoload

  autoload :NotificationApi,  'activity_notification/apis/notification_api'
  autoload :Notification,     'activity_notification/models/notification'
  autoload :Target,           'activity_notification/models/concerns/target'
  autoload :Notifiable,       'activity_notification/models/concerns/notifiable'
  autoload :Notifier,         'activity_notification/models/concerns/notifier'
  autoload :Group,            'activity_notification/models/concerns/group'
  autoload :Common
  autoload :Config
  autoload :Renderable
  autoload :VERSION


  module Mailers
    autoload :Helpers,        'activity_notification/mailers/helpers'
  end

  # Returns configuration object of ActivityNotification.
  def self.config
    @config ||= ActivityNotification::Config.new
  end

  # Sets global configuration options for ActivityNotification.
  # All available options and their defaults are in the example below:
  # @example Initializer for Rails
  #   ActivityNotification.configure do |config|
  #     config.enabled            = true
  #     config.table_name         = "notifications"
  #     config.email_enabled      = false
  #     config.mailer_sender      = nil
  #     config.mailer             = 'ActivityNotification::Mailer'
  #     config.parent_mailer      = 'ActionMailer::Base'
  #     config.parent_controller  = 'ApplicationController'
  #     config.opened_index_limit = 10
  #   end
  def self.configure(&block)
    yield(config) if block_given?
  end

end

# Load ActivityNotification helpers
require 'activity_notification/helpers/polymorphic_helpers'
require 'activity_notification/helpers/view_helpers'
require 'activity_notification/controllers/store_controller'

# Load role for models
require 'activity_notification/models'

# Define Rails::Engine
require 'activity_notification/rails'
