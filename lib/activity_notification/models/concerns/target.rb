module ActivityNotification
  # Target implementation included in target model to notify, like users or administrators.
  module Target
    extend ActiveSupport::Concern
    included do
      include Common

      # Has many notification instances of this target.
      # @scope instance
      # @return [Array<Notificaion>] Array or database query of notifications of this target
      has_many :notifications,
        class_name: "::ActivityNotification::Notification",
        as: :target,
        dependent: :delete_all

      class_attribute :_notification_email,
                      :_notification_email_allowed,
                      :_notification_devise_resource,
                      :_printable_notification_target_name
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
        self._notification_email                 = nil
        self._notification_email_allowed         = ActivityNotification.config.email_enabled
        self._notification_devise_resource       = ->(model) { model }
        self._printable_notification_target_name = :printable_name
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
      unless current_resource.blank? or current_resource.instance_of? devise_resource.class
        raise TypeError,
          "Defferent type of current resource #{current_resource.class} "\
          "with devise resource #{devise_resource.class} has been passed to #{self.class}##{__method__}. "\
          "You have to override #{self.class}##{__method__} method or set devise_resource in acts_as_target."
      end
      current_resource.present? and current_resource == devise_resource
    end

    # Returns printable target model name to show in view or email.
    # @return [String] Printable target model name
    def printable_target_name
      resolve_value(_printable_notification_target_name)
    end

    # Returns count of unopened notifications of the target.
    #
    # @param [Hash] options Options for notification index
    # @option options [Integer] :limit                  (nil) Limit to query for notifications
    # @return [Integer] Count of unopened notifications of the target
    # @todo Add filter and reverse options
    def unopened_notification_count(options = {})
      unopened_notification_index(options).count
    end

    # Returns if the target has unopened notifications.
    #
    # @param [Hash] options Options for notification index
    # @option options [Integer] :limit                  (nil) Limit to query for notifications
    # @return [Boolean] If the target has unopened notifications
    # @todo Add filter and reverse options
    def has_unopened_notifications?(options = {})
      unopened_notification_index(options).present?
    end

    # Gets automatically arranged notification index of the target.
    # This method is the typical way to get notifications index from controller of view.
    # When the target have unopened notifications, it returns unopened notifications first.
    # Additionaly, it returns opened notifications unless unopened index size overs the limit.
    # @todo Is this switching the best solution?
    #
    # @example Get automatically arranged notification index of the @user
    #   @notifications = @user.notification_index
    #
    # @param [Hash] options Options for notification index
    # @option options [Integer] :limit                  (nil) Limit to query for notifications
    # @return [Array<Notificaion>] Notification index of the target
    # @todo Add filter and reverse options
    def notification_index(options = {})
      # When the target have unopened notifications
      has_unopened_notifications?(options) ?
        # Return unopened notifications
        unopened_notification_index(options) :
        # Otherwise, return opened notifications
        opened_notification_index(options)

      # When the target have unopened notifications
      if has_unopened_notifications?(options)
        # Total limit if notification index
        total_limit = options[:limit] || ActivityNotification.config.opened_index_limit
        # Return unopened notifications first
        target_unopened_index = unopened_notification_index(options).to_a
        # Additionaly, return opened notifications unless unopened index size overs the limit
        if (opened_limit = total_limit - target_unopened_index.size) > 0
          target_opened_index = opened_notification_index(options.merge(limit: opened_limit))
          target_unopened_index.concat(target_opened_index.to_a)
        else
          target_unopened_index
        end
      else
        # Otherwise, return opened notifications
        opened_notification_index(options)
      end
    end

    # Gets unopened notification index of the target.
    #
    # @example Get unopened notification index of the @user
    #   @notifications = @user.unopened_notification_index
    #
    # @param [Hash] options Options for notification index
    # @option options [Integer] :limit                  (nil) Limit to query for notifications
    # @return [Array<Notificaion>] Unopened notification index of the target
    # @todo Add filter and reverse options
    def unopened_notification_index(options = {})
      options[:limit].present? ?
        notifications.unopened_index.limit(options[:limit]) :
        notifications.unopened_index
    end

    # Gets opened notification index of the target.
    #
    # @example Get opened notification index of the @user
    #   @notifications = @user.opened_notification_index(10)
    #
    # @param [Hash] options Options for notification index
    # @option options [Integer] :limit                  (ActivityNotification.config.opened_index_limit) Limit to query for notifications
    # @return [Array<Notificaion>] Opened notification index of the target
    # @todo Add filter and reverse options
    def opened_notification_index(options = {})
      limit = options[:limit] || ActivityNotification.config.opened_index_limit
      notifications.opened_index(limit)
    end

    # Generates notifications to this target.
    # This method calls NotificationApi#notify_to internally with self target instance.
    # @see NotificationApi#notify_to
    #
    # @param [Object] notifiable Notifiable instance to notify
    # @param [Hash] options Options for notifications
    # @option options [String]  :key        (notifiable.default_notification_key) Key of the notification
    # @option options [Object]  :group      (nil)                                 Group unit of the notifications
    # @option options [Object]  :notifier   (nil)                                 Notifier of the notifications
    # @option options [Hash]    :parameters ({})                                  Additional parameters of the notifications
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
    # @option options [String]   :filtered_by_type       (nil) Notifiable type for filter
    # @option options [Object]   :filtered_by_group      (nil) Group instance for filter
    # @option options [String]   :filtered_by_group_type (nil) Group type for filter, valid with :filtered_by_group_id
    # @option options [String]   :filtered_by_group_id   (nil) Group instance id for filter, valid with :filtered_by_group_type
    # @option options [String]   :filtered_by_key        (nil) Key of the notification for filter
    # @return [Integer] Number of opened notification records
    def open_all_notifications(options = {})
      Notification.open_all_of(self, options)
    end


    # Gets automatically arranged notification index of the target with included attributes like target, notifiable, group and notifier.
    # This method is the typical way to get notifications index from controller of view.
    # When the target have unopened notifications, it returns unopened notifications first.
    # Additionaly, it returns opened notifications unless unopened index size overs the limit.
    # @todo Is this switching the best solution?
    #
    # @example Get automatically arranged notification index of the @user with included attributes
    #   @notifications = @user.notification_index_with_attributes
    #
    # @param [Hash] options Options for notification index
    # @option options [Integer] :limit                  (nil) Limit to query for notifications
    # @return [Array<Notificaion>] Notification index of the target with attributes
    # @todo Add filter and reverse options
    def notification_index_with_attributes(options = {})
      # When the target have unopened notifications
      if has_unopened_notifications?(options)
        # Total limit if notification index
        total_limit = options[:limit] || ActivityNotification.config.opened_index_limit
        # Return unopened notifications first
        target_unopened_index = unopened_notification_index_with_attributes(options).to_a
        # Additionaly, return opened notifications unless unopened index size overs the limit
        if (opened_limit = total_limit - target_unopened_index.size) > 0
          target_opened_index = opened_notification_index_with_attributes(options.merge(limit: opened_limit))
          target_unopened_index.concat(target_opened_index.to_a)
        else
          target_unopened_index
        end
      else
        # Otherwise, return opened notifications
        opened_notification_index_with_attributes(options)
      end
    end

    # Gets unopened notification index of the target with included attributes like target, notifiable, group and notifier.
    #
    # @example Get unopened notification index of the @user with included attributes
    #   @notifications = @user.unopened_notification_index_with_attributes
    #
    # @param [Hash] options Options for notification index
    # @option options [Integer] :limit                  (nil) Limit to query for notifications
    # @return [Array<Notificaion>] Unopened notification index of the target with attributes
    # @todo Add filter and reverse options
    def unopened_notification_index_with_attributes(options = {})
      include_attributes unopened_notification_index(options)
    end

    # Gets opened notification index of the target with including attributes like target, notifiable, group and notifier.
    #
    # @example Get opened notification index of the @user with included attributes
    #   @notifications = @user.opened_notification_index_with_attributes(10)
    #
    # @param [Hash] options Options for notification index
    # @option options [Integer] :limit                  (ActivityNotification.config.opened_index_limit) Limit to query for notifications
    # @return [Array<Notificaion>] Opened notification index of the target with attributes
    # @todo Add filter and reverse options
    def opened_notification_index_with_attributes(options = {})
      include_attributes opened_notification_index(options)
    end

    private

      # Includes attributes like target, notifiable, group or notifier from the notification index.
      # When group member exists in the notification index, group will be included in addition to target, notifiable and or notifier.
      # Otherwise, target, notifiable and or notifier will be include without group.
      # @api private
      #
      # @param [ActiveRecord_AssociationRelation<Notificaion>] target_index Notification index
      # @return [ActiveRecord_AssociationRelation<Notificaion>] Notification index with attributes
      def include_attributes(target_index)
        if target_index.present?
          Notification.group_member_exists?(target_index) ?
            target_index.with_target.with_notifiable.with_group.with_notifier :
            target_index.with_target.with_notifiable.with_notifier
        else
          Notification.none
        end
      end

  end
end