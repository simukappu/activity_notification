module ActivityNotification
  module ActsAsTarget
    extend ActiveSupport::Concern

    class_methods do
      def acts_as_target(opts = {})
        include Target
        options = opts.clone
        if options[:skip_email] == true
          self.send("_notification_email_allowed=".to_sym, false)
        end
        assign_target_globals(options)
        nil
      end
      alias_method :acts_as_notification_target, :acts_as_target

      def available_target_options
        [:skip_email, :email, :email_allowed].freeze
      end

      def assign_target_globals(options)
        [:email, :email_allowed].each do |key|
          if options[key]
            self.send("_notification_#{key}=".to_sym, options.delete(key))
          end
        end
      end
    end
  end
end
