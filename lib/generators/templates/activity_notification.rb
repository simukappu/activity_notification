ActivityNotification.configure do |config|

  # Configure if all activity notifications are enabled
  # Set false when you want to turn off activity notifications
  config.enabled = true

  # Configure table name to store notification data
  config.table_name = "notifications"

  # Configure if email notification is enabled as default
  # Note that you can configure them for each model by acts_as roles.
  # Set true when you want to turn on email notifications as default
  config.email_enabled = false

  # Configure the e-mail address which will be shown in ActivityNotification::Mailer,
  # note that it will be overwritten if you use your own mailer class with default "from" parameter.
  config.mailer_sender = 'please-change-me-at-config-initializers-activity_notification@example.com'

  # Configure the class responsible to send e-mails.
  # config.mailer = "ActivityNotification::Mailer"

  # Configure the parent class responsible to send e-mails.
  # config.parent_mailer = 'ActionMailer::Base'

  # Configure default limit number of opened notifications you can get from opened* scope
  config.opened_index_limit = 10

end
