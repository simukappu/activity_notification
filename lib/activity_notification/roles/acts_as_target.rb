module ActivityNotification
  module ActsAsTarget
    extend ActiveSupport::Concern

    class_methods do
      def acts_as_target(options = {})
        include Target
        if options[:skip_email] == true
          self.send("_notification_email_allowed=".to_sym, false)
          options.delete(:email_allowed)
        end
        [:email, :email_allowed].map { |key|
          options[key] ?
            [key, self.send("_notification_#{key}=".to_sym, options.delete(key))] :
            [nil, nil]
        }.to_h.delete_if { |k, v| k.nil? }
      end
      alias_method :acts_as_notification_target, :acts_as_target

      def available_target_options
        [:skip_email, :email, :email_allowed].freeze
      end
    end
  end
end
