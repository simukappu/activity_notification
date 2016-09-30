class ActivityNotification::MailerPreview < ActionMailer::Preview

  def send_notification_email_single
    target_notification = ActivityNotification::Notification.where(group: nil).first
    ActivityNotification::Mailer.send_notification_email(target_notification)
  end

  def send_notification_email_with_group
    target_notification = ActivityNotification::Notification.where.not(group: nil).first
    ActivityNotification::Mailer.send_notification_email(target_notification)
  end

end