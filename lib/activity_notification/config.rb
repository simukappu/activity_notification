module ActivityNotification
  # Class used to initialize configuration object.
  class Config
    # @overload enabled
    #   Returns whether ActivityNotification is enabled
    #   @return [Boolean] Whether ActivityNotification is enabled.
    # @overload enabled=(value)
    #   Sets whether ActivityNotification is enabled
    #   @param [Boolean] enabled The new enabled
    #   @return [Boolean] Whether ActivityNotification is enabled.
    attr_accessor :enabled

    # @deprecated as of 1.1.0
    # @overload table_name
    #   Returns table name to store notifications
    #   @return [String] Table name to store notifications.
    # @overload table_name=(value)
    #   Sets table name to store notifications
    #   @param [String] table_name The new notification_table_name
    #   @return [String] Table name to store notifications.
    attr_accessor :table_name

    # @overload notification_table_name
    #   Returns table name to store notifications
    #   @return [String] Table name to store notifications.
    # @overload notification_table_name=(value)
    #   Sets table name to store notifications
    #   @param [String] notification_table_name The new notification_table_name
    #   @return [String] Table name to store notifications.
    attr_accessor :notification_table_name

    # @overload subscription_table_name
    #   Returns table name to store subscriptions
    #   @return [String] Table name to store subscriptions.
    # @overload subscription_table_name=(value)
    #   Sets table name to store subscriptions
    #   @param [String] notification_table_name The new subscription_table_name
    #   @return [String] Table name to store subscriptions.
    attr_accessor :subscription_table_name

    # @overload email_enabled
    #   Returns whether activity_notification sends notification email
    #   @return [Boolean] Whether activity_notification sends notification email.
    # @overload email_enabled=(value)
    #   Sets whether activity_notification sends notification email
    #   @param [Boolean] email_enabled The new email_enabled
    #   @return [Boolean] Whether activity_notification sends notification email.
    attr_accessor :email_enabled

    # @overload subscription_enabled
    #   Returns whether activity_notification manages subscriptions
    #   @return [Boolean] Whether activity_notification manages subscriptions.
    # @overload subscription_enabled=(value)
    #   Sets whether activity_notification manages subscriptions
    #   @param [Boolean] subscription_enabled The new subscription_enabled
    #   @return [Boolean] Whether activity_notification manages subscriptions.
    attr_accessor :subscription_enabled

    # @overload subscribe_as_default
    #   Returns default subscription value to use when the subscription record does not configured
    #   @return [Boolean] Default subscription value to use when the subscription record does not configured.
    # @overload default_subscription=(value)
    #   Sets default subscription value to use when the subscription record does not configured
    #   @param [Boolean] subscribe_as_default The new subscribe_as_default
    #   @return [Boolean] Default subscription value to use when the subscription record does not configured.
    attr_accessor :subscribe_as_default

    # @overload mailer_sender
    #   Returns email address as sender of notification email
    #   @return [String] Email address as sender of notification email.
    # @overload mailer_sender=(value)
    #   Sets email address as sender of notification email
    #   @param [String] mailer_sender The new mailer_sender
    #   @return [String] Email address as sender of notification email.
    attr_accessor :mailer_sender

    # @overload mailer
    #   Returns mailer class for email notification
    #   @return [String] Mailer class for email notification.
    # @overload mailer=(value)
    #   Sets mailer class for email notification
    #   @param [String] mailer The new mailer
    #   @return [String] Mailer class for email notification.
    attr_accessor :mailer

    # @overload parent_mailer
    #   Returns base mailer class for email notification
    #   @return [String] Base mailer class for email notification.
    # @overload parent_mailer=(value)
    #   Sets base mailer class for email notification
    #   @param [String] parent_mailer The new parent_mailer
    #   @return [String] Base mailer class for email notification.
    attr_accessor :parent_mailer

    # @overload parent_controller
    #   Returns base controller class for notifications_controller
    #   @return [String] Base controller class for notifications_controller.
    # @overload parent_controller=(value)
    #   Sets base controller class for notifications_controller
    #   @param [String] parent_controller The new parent_controller
    #   @return [String] Base controller class for notifications_controller.
    attr_accessor :parent_controller

    # @overload opened_index_limit
    #   Returns default limit to query for opened notifications
    #   @return [Integer] Default limit to query for opened notifications.
    # @overload opened_index_limit=(value)
    #   Sets default limit to query for opened notifications
    #   @param [Integer] opened_index_limit The new opened_index_limit
    #   @return [Integer] Default limit to query for opened notifications.
    attr_accessor :opened_index_limit

    # @overload :orm
    #   Returns ORM name for ActivityNotification (:active_record or :mongoid)
    #   @return [Boolean] ORM name for ActivityNotification (:active_record or :mongoid).
    attr_reader :orm

    # Initialize configuration for ActivityNotification.
    # These configuration can be overriden in initializer.
    # @return [Config] A new instance of Config
    def initialize
      @enabled                 = true
      @notification_table_name = 'notifications'
      @subscription_table_name = 'subscriptions'
      @email_enabled           = false
      @subscription_enabled    = false
      @subscribe_as_default    = true
      @mailer_sender           = nil
      @mailer                  = 'ActivityNotification::Mailer'
      @parent_mailer           = 'ActionMailer::Base'
      @parent_controller       = 'ApplicationController'
      @opened_index_limit      = 10
      @orm                     = :active_record
    end

    # Sets ORM name for ActivityNotification (:active_record or :mongoid)
    # @param [Symbol, String] orm The new ORM name for ActivityNotification (:active_record or :mongoid)
    # @return [Symbol] ORM name for ActivityNotification (:active_record or :mongoid).
    def orm=(orm)
      @orm = orm.to_sym
    end
  end
end
