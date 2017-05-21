ActivityNotification.configure do |config|

  # Configure ORM name for ActivityNotification.
  # Set :active_record or :mongoid.
  ENV['AN_ORM'] = 'active_record' unless ENV['AN_ORM'] == 'mongoid'
  config.orm = ENV['AN_ORM']

  # Configure if all activity notifications are enabled.
  # Set false when you want to turn off activity notifications.
  config.enabled = true

  # Configure table name to store notification data.
  config.notification_table_name = "notifications"

  # Configure table name to store subscription data.
  config.subscription_table_name = "subscriptions"

  # Configure if email notification is enabled as default.
  # Note that you can configure them for each model by acts_as roles.
  # Set true when you want to turn on email notifications as default.
  config.email_enabled = false

  # Configure if subscription is managed.
  # Note that this parameter must be true when you want use subscription management.
  # However, you can also configure them for each model by acts_as roles.
  # Set true when you want to turn on subscription management as default.
  config.subscription_enabled = false

  # Configure default subscription value to use when the subscription record does not configured.
  # Note that you can configure them for each method calling as default argument.
  # Set false when you want to unsubscribe to any notifications as default.
  config.subscribe_as_default = true

  # Configure the e-mail address which will be shown in ActivityNotification::Mailer,
  # note that it will be overwritten if you use your own mailer class with default "from" parameter.
  config.mailer_sender = 'please-change-me-at-config-initializers-activity_notification@example.com'

  # Configure the class responsible to send e-mails.
  # config.mailer = "ActivityNotification::Mailer"

  # Configure the parent class responsible to send e-mails.
  # config.parent_mailer = 'ActionMailer::Base'

  # Configure the parent class for activity_notification controllers.
  # config.parent_controller = 'ApplicationController'

  # Configure default limit number of opened notifications you can get from opened* scope
  config.opened_index_limit = 10

end
