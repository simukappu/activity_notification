if defined?(ActionMailer)
  class ActivityNotification::Mailer < ActivityNotification.config.parent_mailer.constantize
    include ActivityNotification::Mailers::Helpers

    def send_notification_email(notification)
      if notification.target.notification_email_allowed?(notification.notifiable, notification.key) and 
         notification.notifiable.notification_email_allowed?(notification.target, notification.key)
        notification_mail(notification)
      end
    end
  
  end
end