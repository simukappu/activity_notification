module ActivityNotification
  module ActsAsTarget
    extend ActiveSupport::Concern

    #TODO From Rails 4.2
    #class_methods do
    module ClassMethods
      def acts_as_target(opts = {})
        options = opts.clone
        if options[:skip_email] == true
          self.send("_notification_email_allowed=".to_sym, false)
        end

        assign_globals       options
        nil
      end
      alias_method :acts_as_notification_target, :acts_as_target

      def available_options
        [:skip_email, :email, :email_allowed].freeze
      end

      def assign_globals(options)
        [:email, :email_allowed].each do |key|
          if options[key]
            self.send("_notification_#{key}=".to_sym, options.delete(key))
          end
        end
      end
    end
  end
end
