module ActivityNotification
  # Target implementation included in target model to notify, like users or administrators.
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
      # Checks if the model includes target and target methods are available.
      # @return [Boolean] Always true
      def available_as_target?
        true
      end

      # Sets default values to target class fields.
      # @return [Nil] nil
      def set_target_class_defaults
        self._notification_email            = nil
        self._notification_email_allowed    = ActivityNotification.config.email_enabled
        self._notification_devise_resource  = ->(model) { model }
        nil
      end
    end

    # Returns target email address for email notification.
    # This method is able to be overriden.
    #
    # @return [String] Target email address
    def mailer_to
      resolve_value(_notification_email)
    end

    # Returns if sending notification email is allowed for the target from configured field or overriden method.
    # This method is able to be overriden.
    #
    # @param [Object] notifiable Notifiable instance of the notification
    # @param [String] key Key of the notification
    # @return [Boolean] If sending notification email is allowed for the target
    def notification_email_allowed?(notifiable, key)
      resolve_value(_notification_email_allowed, notifiable, key)
    end

    # Returns if current resource signed in with Devise is authenticated for the notification.
    # This method is able to be overriden.
    #
    # @param [Object] current_resource Current resource signed in with Devise
    # @return [Boolean] If current resource signed in with Devise is authenticated for the notification
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

    # Returns count of unopened notifications of the target.
    #
    # @return [Integer] Count of unopened notifications of the target
    def unopened_notification_count
      unopened_notification_index.count
    end

    # Returns if the target has unopened notifications.
    #
    # @return [Boolean] If the target has unopened notifications
    def has_unopened_notifications?
      unopened_notification_index.exists?
    end

    # Gets automatically arranged notification index of the target.
    # When the target has unopened notifications, returns unopened index with unopened_notification_index.
    # Otherwise, returns opened index with opened_notification_index.
    # @todo Is this switching the best solution?
    #
    # @param [Integer] limit Limit to query for notifications
    # @return [Array] Notification index of the target
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

    # Gets unopened notification index of the target.
    #
    # @param [Integer] limit Limit to query for notifications
    # @return [Array] Unopened notification index of the target
    def unopened_notification_index(limit = nil)
      limit.present? ?
        notifications.unopened_index.limit(limit) :
        notifications.unopened_index
    end

    # Gets opened notification index of the target.
    #
    # @param [Integer] limit Limit to query for notifications
    # @return [Array] Opened notification index of the target
    def opened_notification_index(limit = ActivityNotification.config.opened_limit)
      notifications.opened_index(limit)
    end

    # Generates notifications to this target.
    # This method calls NotificationApi#notify_to internally with self target instance.
    # @see NotificationApi#notify_to
    #
    # @param [Object] notifiable Notifiable instance to notify
    # @param [Hash] options Options for notifications
    # @option options [String]  :key        (notifiable.default_notification_key) Notification key
    # @option options [Object]  :group      (nil)                                 Group of the notifications
    # @option options [Hash]    :parameters ({})                                  Additional parameters of the notifications
    # @option options [Object]  :notifier   (nil)                                 Notifier of the notifications
    # @option options [Boolean] :send_email (true)                                Whether it sends notification email
    # @option options [Boolean] :send_later (true)                                Whether it sends notification email asynchronously
    # @return [Notification] Generated notification instance
    def notify_to(notifiable, options = {})
      Notification.notify_to(self, notifiable, options)
    end
  
    # Opens all notifications of this target.
    # This method calls NotificationApi#open_all_of internally with self target instance.
    # @see NotificationApi#open_all_of
    #
    # @param [Hash] options Options for opening notifications
    # @option options [DateTime] :opened_at (DateTime.now) Time to set to opened_at of the notification record
    # @return [Integer] Number of opened notification records
    # @todo Add filter option
    def open_all_notifications(options = {})
      Notification.open_all_of(self, options)
    end


    # Gets automatically arranged notification index of the target with including attributes like target, notifiable, group and notifier.
    # This method is the typical way to get notifications index from controller of view.
    #
    # @param [Integer] limit Limit to query for notifications
    # @return [Array] Notification index of the target with attributes
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

    # Gets unopened notification index of the target with including attributes like target, notifiable, group and notifier.
    #
    # @param [Integer] limit Limit to query for notifications
    # @return [Array] Unopened notification index of the target with attributes
    def unopened_notification_index_with_attributes(limit = nil)
      include_attributes unopened_notification_index(limit)
    end

    # Gets opened notification index of the target with including attributes like target, notifiable, group and notifier.
    #
    # @param [Integer] limit Limit to query for notifications
    # @return [Array] Opened notification index of the target with attributes
    def opened_notification_index_with_attributes(limit = ActivityNotification.config.opened_limit)
      include_attributes opened_notification_index(limit)
    end

    private

      # Includes attributes like target, notifiable, group or notifier from the notification index.
      # When group member exists in the notification index, group will be included in addition to target, notifiable and or notifier.
      # Otherwise, target, notifiable and or notifier will be include without group.
      # @api private
      #
      # @param [Array] Notification index
      # @return [Array] Notification index with attributes
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