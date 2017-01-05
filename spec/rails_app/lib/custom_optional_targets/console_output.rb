module CustomOptionalTarget
  # Optional target implementation for mobile push notification or SMS using AWS SNS.
  class ConsoleOutput < ActivityNotification::OptionalTarget::Base
    def initialize_target(options = {})
    end

    def notify(notification, options = {})
      puts "----- Optional targets: #{self.class.name} -----"
      puts render_notification_message(notification, options)
      puts "-----------------------------------------------------------------"
    end
  end
end