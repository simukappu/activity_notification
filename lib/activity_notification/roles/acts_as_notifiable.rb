module ActivityNotification
  module ActsAsNotifiable
    extend ActiveSupport::Concern

    class_methods do
      # Adds required callbacks for creating and updating notifiable models.
      #
      # == Parameters:
      # [:targets, :group, :notifier, :parameters, :email_allowed, :notifiable_path]
      # targets:         Targets to send notification. It it set as ActiveRecord records or array of models.
      #                  This is a only necessary option. If you do not specify this option, you have to override
      #                  notification_targets or notification_[plural target type] (e.g. notification_users) method.
      #
      # group:           Group unit of notifications. Notifications will be bundled by this group (and target, notifiable_type, key).
      #                  This parameter is a optional.
      #
      # notifier:        Notifier of the notification.This will be stored as notifier with notification record.
      #                  This parameter is a optional.
      #
      # parameters:      Parameter to add notification data. This will be stored as parameters with notification record.
      #                  This parameter is a optional.
      #
      # email_allowed:   If activity_notification sends notification email to these targets.
      #                  Specified method or symbol is expected to return true (not nil) or false (nil).
      #                  This parameter is a optional since default value is false.
      #                  To use notification email, email_allowed option must return true (not nil) in both of notifiable and target model.
      #                  This can be also configured default option in initializer.
      #
      # notifiable_path: Path to redirect from open or move action of notification controller.
      #                  You can use this notifiable_path as notifiable link in notification view.
      #                  This parameter is a optional since polymorphic_path is used as default value.
      def acts_as_notifiable(target_type, options = {})
        include Notifiable
        (
          [:targets, :group, :parameters, :email_allowed].map { |key|
            options[key] ?
              [key, self.send("_notification_#{key}".to_sym).store(target_type.to_sym, options.delete(key))] :
              [nil, nil]
          }.to_h.merge [:notifier, :notifiable_path].map { |key|
            options[key] ?
              [key, self.send("_#{key}".to_sym).store(target_type.to_sym, options.delete(key))] :
              [nil, nil]
          }.to_h
        ).delete_if { |k, v| k.nil? }
      end

      def available_notifiable_options
        [:targets, :group, :notifier, :parameters, :email_allowed, :notifiable_path].freeze
      end
    end
  end
end
