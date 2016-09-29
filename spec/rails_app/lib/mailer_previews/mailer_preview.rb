class ActivityNotification::MailerPreview < ActionMailer::Preview
  def send_notification_email
    ActivityNotification::Mailer.send_notification_email(ActivityNotification::Notification.first)
  end
end