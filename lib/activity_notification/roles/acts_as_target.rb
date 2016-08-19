module ActivityNotification
  module ActsAsTarget
    extend ActiveSupport::Concern

    class_methods do
      def acts_as_target(options = {})
        include Target
        available_target_options.map { |key|
          options[key] ?
            [key, self.send("_notification_#{key}=".to_sym, options.delete(key))] :
            [nil, nil]
        }.to_h.delete_if { |k, v| k.nil? }
      end
      alias_method :acts_as_notification_target, :acts_as_target

      def available_target_options
        [:email, :email_allowed, :devise_resource].freeze
      end
    end
  end
end
