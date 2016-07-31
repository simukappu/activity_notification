ActivityNotification.configure do |config|

  # Table name to store notification data
  config.table_name = "notifications"

  # ==> Mailer Configuration
  # Configure the e-mail address which will be shown in ActivityNotification::Mailer,
  # note that it will be overwritten if you use your own mailer class with default "from" parameter.
  config.mailer_sender = 'please-change-me-at-config-initializers-activity_notification@example.com'

  # Configure the class responsible to send e-mails.
  # config.mailer = "ActivityNotification::Mailer"

  # Configure the parent class responsible to send e-mails.
  # config.parent_mailer = 'ActionMailer::Base'
    
  config.opened_limit = 10
end
