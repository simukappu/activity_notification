module ActivityNotification
  # Class used to initialize configuration object.
  class Config
    # @overload enabled
    #   @return [Boolean] Whether ActivityNotification is enabled.
    # @overload enabled=(value)
    #   Sets the enabled
    #   @param [Boolean] enabled The new enabled
    #   @return [Boolean] Whether ActivityNotification is enabled.
    attr_accessor :enabled

    # @overload table_name
    #   @return [String] Table name to store notifications.
    # @overload table_name=(value)
    #   Sets the table_name
    #   @param [String] table_name The new table_name
    #   @return [String] Table name to store notifications.
    attr_accessor :table_name

    # @overload email_enabled
    #   @return [Boolean] Whether activity_notification sends notification email.
    # @overload email_enabled=(value)
    #   Sets the email_enabled
    #   @param [Boolean] email_enabled The new email_enabled
    #   @return [Boolean] Whether activity_notification sends notification email.
    attr_accessor :email_enabled

    # @overload mailer_sender
    #   @return [String] Email address as sender of notification email.
    # @overload mailer_sender=(value)
    #   Sets the mailer_sender
    #   @param [String] mailer_sender The new mailer_sender
    #   @return [String] Email address as sender of notification email.
    attr_accessor :mailer_sender

    # @overload mailer
    #   @return [String] Mailer class for email notification.
    # @overload mailer=(value)
    #   Sets the mailer
    #   @param [String] mailer The new mailer
    #   @return [String] Mailer class for email notification.
    attr_accessor :mailer

    # @overload parent_mailer
    #   @return [String] Base mailer class for email notification.
    # @overload parent_mailer=(value)
    #   Sets the parent_mailer
    #   @param [String] parent_mailer The new parent_mailer
    #   @return [String] Base mailer class for email notification.
    attr_accessor :parent_mailer

    # @overload parent_controller
    #   @return [String] Base controller class for notifications_controller.
    # @overload parent_controller=(value)
    #   Sets the parent_controller
    #   @param [String] parent_controller The new parent_controller
    #   @return [String] Base controller class for notifications_controller.
    attr_accessor :parent_controller

    # @overload opened_limit
    #   @return [Integer] Default limit to query for opened notifications.
    # @overload opened_limit=(value)
    #   Sets the opened_limit
    #   @param [Integer] opened_limit The new opened_limit
    #   @return [Integer] Default limit to query for opened notifications.
    attr_accessor :opened_limit

    # Initialize configuration for ActivityNotification.
    # These configuration can be overriden in initializer.
    # @return [Config] A new instance of Config
    def initialize
      @enabled           = true
      @table_name        = 'notifications'
      @email_enabled     = false
      @mailer_sender     = nil
      @mailer            = 'ActivityNotification::Mailer'
      @parent_mailer     = 'ActionMailer::Base'
      @parent_controller = 'ApplicationController'
      @opened_limit      = 10
    end

  end
end
