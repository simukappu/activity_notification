if defined?(ActionMailer)
  # Mailer for email notification of ActivityNotificaion.
  class ActivityNotification::Mailer < ActivityNotification.config.parent_mailer.constantize
    include ActivityNotification::Mailers::Helpers

    # Sends notification email.
    # @param [Notification] notification Notification instance to send email
    def send_notification_email(notification, options = {})
      options[:fallback] = :default unless options.has_key?(:fallback)
      options.delete(:fallback) if options[:fallback] == :none
      if notification.target.notification_email_allowed?(notification.notifiable, notification.key) and 
         notification.notifiable.notification_email_allowed?(notification.target, notification.key)
        notification_mail(notification, options)
      end
    end
  
  end
end