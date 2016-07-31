module ActivityNotification
  module ActsAsNotifiable
    extend ActiveSupport::Concern

    class_methods do
      # Adds required callbacks for creating and updating
      # notifiable models.
      #
      # == Parameters:
      # [:targets]
      #TODO
      def acts_as_notifiable(target_type, opts = {})
        include Notifiable
        options = opts.clone
        assign_notifiable_globals(target_type, options)
        nil
      end

      def available_notifiable_options
        [:targets, :group, :notifier, :parameters, :email_allowed, :notifiable_path].freeze
      end

      def assign_notifiable_globals(target_type, options)
        [:targets, :group, :parameters, :email_allowed].each do |key|
          if options[key]
            self.send("_notification_#{key}".to_sym).store(target_type.to_sym, options.delete(key))
          end
        end
        [:notifier, :notifiable_path].each do |key|
          if options[key]
            self.send("_#{key}".to_sym).store(target_type.to_sym, options.delete(key))
          end
        end
      end

    end
  end
end
