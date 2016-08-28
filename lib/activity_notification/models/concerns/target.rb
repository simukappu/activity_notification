module ActivityNotification
  module Target
    extend ActiveSupport::Concern
    included do
      include Common
      has_many :notifications,
        class_name: "::ActivityNotification::Notification",
        as: :target
      class_attribute :_notification_email, :_notification_email_allowed, :_notification_devise_resource
      set_target_class_defaults
    end

    class_methods do
      def available_as_target?
        true
      end

      def set_target_class_defaults
        self._notification_email            = nil
        self._notification_email_allowed    = ActivityNotification.config.email_enabled
        self._notification_devise_resource  = ->(model) { model }
      end
    end

    def mailer_to
      resolve_value(_notification_email)
    end

    def notification_email_allowed?(notifiable, key)
      resolve_value(_notification_email_allowed, notifiable, key)
    end

    def authenticated_with_devise?(current_resource)
      devise_resource = resolve_value(_notification_devise_resource)
      unless current_resource.instance_of? devise_resource.class
        raise TypeError,
          "Defferent type of current resource #{current_resource.class} "\
          "with devise resource #{devise_resource.class} has been passed to #{self.class}##{__method__}. "\
          "You have to override #{self.class}##{__method__} method or set devise_resource in acts_as_target."
      end
      current_resource == devise_resource
    end

    def unopened_notification_count
      unopened_notification_index.count
    end

    def has_unopened_notifications?
      unopened_notification_index.exists?
    end

    #TODO is this switching the best solution?
    def notification_index(limit = nil)
      # When the target have unopened notifications
      notifications.unopened_index.exists? ?
        # Return unopened notifications
        unopened_notification_index(limit) :
        # Otherwise, return opened notifications
        limit.present? ?
          opened_notification_index(limit) :
          opened_notification_index
    end

    def unopened_notification_index(limit = nil)
      limit.present? ?
        notifications.unopened_index.limit(limit) :
        notifications.unopened_index
    end

    def opened_notification_index(limit = ActivityNotification.config.opened_limit)
      notifications.opened_index(limit)
    end


    # Wrapper methods of Notification class methods
  
    def notify_to(notifiable, options = {})
      Notification.notify_to(self, notifiable, options)
    end
  
    def open_all_notifications(options = {})
      Notification.open_all_of(self, options)
    end


    # Methods to be overriden

    # Typical method to get notifications index
    def notification_index_with_attributes(limit = nil)
      # When the target have unopened notifications
      unopened_notification_index.exists? ?
        # Return unopened notifications
        unopened_notification_index_with_attributes(limit) :
        # Otherwise, return opened notifications
        limit.present? ?
          opened_notification_index_with_attributes(limit) :
          opened_notification_index_with_attributes
    end

    def unopened_notification_index_with_attributes(limit = nil)
      include_attributes unopened_notification_index(limit)
    end

    def opened_notification_index_with_attributes(limit = ActivityNotification.config.opened_limit)
      include_attributes opened_notification_index(limit)
    end

    private

      def include_attributes(notification_index)
        if notification_index.present?
          Notification.group_member_exists?(notification_index) ?
            notification_index.with_target.with_notifiable.with_group.with_notifier :
            notification_index.with_target.with_notifiable.with_notifier
        else
          notifications.none
        end
      end

  end
end