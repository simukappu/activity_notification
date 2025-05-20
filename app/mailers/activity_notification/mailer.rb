if defined?(ActionMailer)
  # Mailer for email notification of ActivityNotificaion.
  class ActivityNotification::Mailer < ActivityNotification.config.parent_mailer.constantize
    include ActivityNotification::Mailers::Helpers

    # Sends notification email.
    #
    # @param [Notification] notification Notification instance to send email
    # @param [Hash]         options      Options for notification email
    # @option options [String, Symbol] :fallback (:default) Fallback template to use when MissingTemplate is raised
    # @return [Mail::Message|ActionMailer::DeliveryJob] Email message or its delivery job
    def send_notification_email(notification, options = {})
      # Return nil if notification no longer exists (was destroyed)
      return nil if notification.nil? || !notification.class.exists?(notification.id)
      
      options[:fallback] ||= :default
      if options[:fallback] == :none
        options.delete(:fallback)
      end
      notification_mail(notification, options)
    end

    # Sends batch notification email.
    #
    # @param [Object]              target        Target of batch notification email
    # @param [Array<Notification>] notifications Target notifications to send batch notification email
    # @param [String]              batch_key     Key of the batch notification email
    # @param [Hash]                options       Options for notification email
    # @option options [String, Symbol] :fallback  (:batch_default) Fallback template to use when MissingTemplate is raised
    # @return [Mail::Message|ActionMailer::DeliveryJob] Email message or its delivery job
    def send_batch_notification_email(target, notifications, batch_key, options = {})
      # Return nil if target is nil or notifications are empty
      return nil if target.nil? || notifications.blank?
      
      # Filter out notifications that no longer exist
      valid_notifications = notifications.select { |n| n && n.class.exists?(n.id) }
      return nil if valid_notifications.blank?
      
      options[:fallback] ||= :batch_default
      if options[:fallback] == :none
        options.delete(:fallback)
      end
      batch_notification_mail(target, valid_notifications, batch_key, options)
    end

  end
end