module ActivityNotification
  # Defines API for notification included in Notification model.
  module NotificationApi
    extend ActiveSupport::Concern

    included do
      # Defines store_notification as private clas method
      private_class_method :store_notification
    end

    class_methods do
      # Generates notifications to configured targets with notifiable model.
      #
      # @example Use with target_type as Symbol
      #   ActivityNotification::Notification.notify :users, @comment
      # @example Use with target_type as String
      #   ActivityNotification::Notification.notify 'User', @comment
      # @example Use with target_type as Class
      #   ActivityNotification::Notification.notify User, @comment
      # @example Use with options
      #   ActivityNotification::Notification.notify :users, @comment, key: 'custom.comment', group: @comment.article
      #   ActivityNotification::Notification.notify :users, @comment, parameters: { reply_to: @comment.reply_to }, send_later: false
      #
      # @param [Symbol, String, Class] target_type Type of target
      # @param [Object] notifiable Notifiable instance
      # @param [Hash] options Options for notifications
      # @option options [String]                  :key                (notifiable.default_notification_key) Key of the notification
      # @option options [Object]                  :group              (nil)                                 Group unit of the notifications
      # @option options [ActiveSupport::Duration] :group_expiry_delay (nil)                                 Expiry period of a notification group
      # @option options [Object]                  :notifier           (nil)                                 Notifier of the notifications
      # @option options [Hash]                    :parameters         ({})                                  Additional parameters of the notifications
      # @option options [Boolean]                 :send_email         (true)                                Whether it sends notification email
      # @option options [Boolean]                 :send_later         (true)                                Whether it sends notification email asynchronously        
      # @return [Array<Notificaion>] Array of generated notifications
      def notify(target_type, notifiable, options = {})
        targets = notifiable.notification_targets(target_type, options[:key])
        unless targets.blank?
          notify_all(targets, notifiable, options)
        end
      end

      # Generates notifications to specified targets.
      #
      # @example Notify to all users
      #   ActivityNotification::Notification.notify_all User.all, @comment
      #
      # @param [Array<Object>] targets Targets to send notifications
      # @param [Object] notifiable Notifiable instance
      # @param [Hash] options Options for notifications
      # @option options [String]                  :key                (notifiable.default_notification_key) Key of the notification
      # @option options [Object]                  :group              (nil)                                 Group unit of the notifications
      # @option options [ActiveSupport::Duration] :group_expiry_delay (nil)                                 Expiry period of a notification group
      # @option options [Object]                  :notifier           (nil)                                 Notifier of the notifications
      # @option options [Hash]                    :parameters         ({})                                  Additional parameters of the notifications
      # @option options [Boolean]                 :send_email         (true)                                Whether it sends notification email
      # @option options [Boolean]                 :send_later         (true)                                Whether it sends notification email asynchronously        
      # @return [Array<Notificaion>] Array of generated notifications
      def notify_all(targets, notifiable, options = {})
        targets.map { |target| target.notify_to(notifiable, options) }
      end

      # Generates notifications to one target.
      #
      # @example Notify to one user
      #   ActivityNotification::Notification.notify_to @comment.auther, @comment
      #
      # @param [Object] target Target to send notifications
      # @param [Object] notifiable Notifiable instance
      # @param [Hash] options Options for notifications
      # @option options [String]                  :key                (notifiable.default_notification_key) Key of the notification
      # @option options [Object]                  :group              (nil)                                 Group unit of the notifications
      # @option options [ActiveSupport::Duration] :group_expiry_delay (nil)                                 Expiry period of a notification group
      # @option options [Object]                  :notifier           (nil)                                 Notifier of the notifications
      # @option options [Hash]                    :parameters         ({})                                  Additional parameters of the notifications
      # @option options [Boolean]                 :send_email         (true)                                Whether it sends notification email
      # @option options [Boolean]                 :send_later         (true)                                Whether it sends notification email asynchronously        
      # @return [Notification] Generated notification instance
      def notify_to(target, notifiable, options = {})
        send_email = options.has_key?(:send_email) ? options[:send_email] : true
        send_later = options.has_key?(:send_later) ? options[:send_later] : true
        # Generate notification
        notification = generate_notification(target, notifiable, options)
        # Send notification email
        if notification.present? && send_email
          notification.send_notification_email({ send_later: send_later })
        end
        # Return generated notification
        notification
      end

      # Generates a notification
      # @param [Object] target Target to send notification
      # @param [Object] notifiable Notifiable instance
      # @param [Hash] options Options for notification
      # @option options [String]  :key        (notifiable.default_notification_key) Key of the notification
      # @option options [Object]  :group      (nil)                                 Group unit of the notifications
      # @option options [Object]  :notifier   (nil)                                 Notifier of the notifications
      # @option options [Hash]    :parameters ({})                                  Additional parameters of the notifications
      def generate_notification(target, notifiable, options = {})
        key = options[:key] || notifiable.default_notification_key
        if target.subscribes_to_notification?(key)
          # Store notification
          store_notification(target, notifiable, key, options)
        end
      end

      # Opens all notifications of the target.
      #
      # @param [Object] target Target of the notifications to open
      # @param [Hash] options Options for opening notifications
      # @option options [DateTime] :opened_at              (Time.current) Time to set to opened_at of the notification record
      # @option options [String]   :filtered_by_type       (nil)          Notifiable type for filter
      # @option options [Object]   :filtered_by_group      (nil)          Group instance for filter
      # @option options [String]   :filtered_by_group_type (nil)          Group type for filter, valid with :filtered_by_group_id
      # @option options [String]   :filtered_by_group_id   (nil)          Group instance id for filter, valid with :filtered_by_group_type
      # @option options [String]   :filtered_by_key        (nil)          Key of the notification for filter
      # @return [Integer] Number of opened notification records
      # @todo Add filter option
      def open_all_of(target, options = {})
        opened_at = options[:opened_at] || Time.current
        target.notifications.unopened_only.filtered_by_options(options).update_all(opened_at: opened_at)
      end
  
      # Returns if group member of the notifications exists.
      # This method is designed to be called from controllers or views to avoid N+1.
      #
      # @param [Array<Notificaion>, ActiveRecord_AssociationRelation<Notificaion>] notifications Array or database query of the notifications to test member exists
      # @return [Boolean] If group member of the notifications exists
      def group_member_exists?(notifications)
        notifications.present? && where(group_owner_id: notifications.map(&:id)).exists?
      end

      # Sends batch notification email to the target.
      #
      # @param [Object]              target        Target of batch notification email
      # @param [Array<Notification>] notifications Target notifications to send batch notification email
      # @param [Hash]                options       Options for notification email
      # @option options [Boolean]        :send_later  (false)          If it sends notification email asynchronously
      # @option options [String, Symbol] :fallback    (:batch_default) Fallback template to use when MissingTemplate is raised
      # @option options [String]         :batch_key   (nil)            Key of the batch notification email, a key of the first notification will be used if not specified
      # @return [Mail::Message, ActionMailer::DeliveryJob|NilClass] Email message or its delivery job, return NilClass for wrong target
      def send_batch_notification_email(target, notifications, options = {})
        notifications.blank? and return
        batch_key = options[:batch_key] || notifications.first.key
        if target.batch_notification_email_allowed?(batch_key) &&
           target.subscribes_to_notification_email?(batch_key)
          send_later = options.has_key?(:send_later) ? options[:send_later] : true
          send_later ?
            Mailer.send_batch_notification_email(target, notifications, batch_key, options).deliver_later :
            Mailer.send_batch_notification_email(target, notifications, batch_key, options).deliver_now
        end
      end

      # Returns available options for kinds of notify methods.
      #
      # @return [Array<Notificaion>] Available options for kinds of notify methods
      def available_options
        [:key, :group, :parameters, :notifier, :send_email, :send_later].freeze
      end

      # Stores notifications to datastore
      # @api private
      def store_notification(target, notifiable, key, options = {})
        target_type        = target.to_class_name
        group              = options[:group]              || notifiable.notification_group(target_type, key)
        group_expiry_delay = options[:group_expiry_delay] || notifiable.notification_group_expiry_delay(target_type, key)
        notifier           = options[:notifier]           || notifiable.notifier(target_type, key)
        parameters         = options[:parameters]         || {}
        parameters.merge!(options.except(*available_options))
        parameters.merge!(notifiable.notification_parameters(target_type, key))

        # Bundle notification group by target, notifiable_type, group and key
        # Defferent notifiable.id can be made in a same group
        group_owner_notifications = filtered_by_target(target).filtered_by_type(notifiable.to_class_name).filtered_by_key(key)
                                   .filtered_by_group(group).group_owners_only.unopened_only
        group_owner = group_expiry_delay.present? ?
                        group_owner_notifications.where("created_at > ?", group_expiry_delay.ago).earliest :
                        group_owner_notifications.earliest
        notification_fields = { target: target, notifiable: notifiable, key: key, group: group, parameters: parameters, notifier: notifier }
        group.present? && group_owner.present? ?
          create(notification_fields.merge(group_owner: group_owner)) :
          create(notification_fields)
      end
    end


    # Sends notification email to the target.
    #
    # @param [Hash] options Options for notification email
    # @option options [Boolean]        :send_later            If it sends notification email asynchronously
    # @option options [String, Symbol] :fallback   (:default) Fallback template to use when MissingTemplate is raised
    # @return [Mail::Message, ActionMailer::DeliveryJob] Email message or its delivery job
    def send_notification_email(options = {})
      if target.notification_email_allowed?(notifiable, key) &&
         email_subscribed?(key) &&
         notifiable.notification_email_allowed?(target, key)
        send_later = options.has_key?(:send_later) ? options[:send_later] : true
        send_later ?
          Mailer.send_notification_email(self, options).deliver_later :
          Mailer.send_notification_email(self, options).deliver_now
      end
    end

    # Opens the notification.
    #
    # @param [Hash] options Options for opening notifications
    # @option options [DateTime] :opened_at   (Time.current) Time to set to opened_at of the notification record
    # @option options [Boolean] :with_members (true)         If it opens notifications including group members
    # @return [Integer] Number of opened notification records
    def open!(options = {})
      opened_at = options[:opened_at] || Time.current
      with_members = options.has_key?(:with_members) ? options[:with_members] : true
      update(opened_at: opened_at)
      with_members ? group_members.update_all(opened_at: opened_at) + 1 : 1
    end

    # Returns if the notification is unopened.
    #
    # @return [Boolean] If the notification is unopened
    def unopened?
      !opened?
    end

    # Returns if the notification is opened.
    #
    # @return [Boolean] If the notification is opened
    def opened?
      opened_at.present?
    end

    # Returns if the notification is group owner.
    #
    # @return [Boolean] If the notification is group owner
    def group_owner?
      group_owner_id.blank?
    end

    # Returns if the notification is group member belonging to owner.
    #
    # @return [Boolean] If the notification is group member
    def group_member?
      group_owner_id.present?
    end
  
    # Returns if group member of the notification exists.
    # This method is designed to cache group by query result to avoid N+1 call.
    #
    # @param [Integer] limit Limit to query for opened notifications
    # @return [Boolean] If group member of the notification exists
    def group_member_exists?(limit = ActivityNotification.config.opened_index_limit)
      group_member_count(limit) > 0
    end

    # Returns if group member notifier except group owner notifier exists.
    # It always returns false if group owner notifier is blank.
    # It counts only the member notifier of the same type with group owner notifier.
    # This method is designed to cache group by query result to avoid N+1 call.
    #
    # @param [Integer] limit Limit to query for opened notifications
    # @return [Boolean] If group member of the notification exists
    def group_member_notifier_exists?(limit = ActivityNotification.config.opened_index_limit)
      group_member_notifier_count(limit) > 0
    end

    # Returns count of group members of the notification.
    # This method is designed to cache group by query result to avoid N+1 call.
    #
    # @param [Integer] limit Limit to query for opened notifications
    # @return [Integer] Count of group members of the notification
    def group_member_count(limit = ActivityNotification.config.opened_index_limit)
      meta_group_member_count(:opened_group_member_count, :unopened_group_member_count, limit)
    end

    # Returns count of group notifications including owner and members.
    # This method is designed to cache group by query result to avoid N+1 call.
    #
    # @param [Integer] limit Limit to query for opened notifications
    # @return [Integer] Count of group notifications including owner and members
    def group_notification_count(limit = ActivityNotification.config.opened_index_limit)
      group_member_count(limit) + 1
    end

    # Returns count of group member notifiers of the notification not including group owner notifier.
    # It always returns 0 if group owner notifier is blank.
    # It counts only the member notifier of the same type with group owner notifier.
    # This method is designed to cache group by query result to avoid N+1 call.
    #
    # @param [Integer] limit Limit to query for opened notifications
    # @return [Integer] Count of group member notifiers of the notification
    def group_member_notifier_count(limit = ActivityNotification.config.opened_index_limit)
      meta_group_member_count(:opened_group_member_notifier_count, :unopened_group_member_notifier_count, limit)
    end

    # Returns count of group member notifiers including group owner notifier.
    # It always returns 0 if group owner notifier is blank.
    # This method is designed to cache group by query result to avoid N+1 call.
    #
    # @param [Integer] limit Limit to query for opened notifications
    # @return [Integer] Count of group notifications including owner and members
    def group_notifier_count(limit = ActivityNotification.config.opened_index_limit)
      notification = group_member? ? group_owner : self
      notification.notifier.present? ? group_member_notifier_count(limit) + 1 : 0
    end

    # Returns the latest group member notification instance of this notification.
    # If this group owner has no group members, group owner instance self will be returned.
    #
    # @return [Notificaion] Notification instance of the latest group member notification
    def latest_group_member
      notification = group_member? ? group_owner : self
      notification.group_member_exists? ? notification.group_members.latest : self
    end

    # Remove from notification group and make a new group owner.
    #
    # @return [Notificaion] New group owner instance of the notification group
    def remove_from_group
      new_group_owner = group_members.earliest
      if new_group_owner.present?
        new_group_owner.update(group_owner_id: nil)
        group_members.update_all(group_owner_id: new_group_owner)
      end
      new_group_owner
    end

    # Returns notifiable_path to move after opening notification with notifiable.notifiable_path.
    #
    # @return [String] Notifiable path URL to move after opening notification
    def notifiable_path
      notifiable.present? or raise ActiveRecord::RecordNotFound.new("Couldn't find notifiable #{notifiable_type}")
      notifiable.notifiable_path(target_type, key)
    end

    # Returns if the target subscribes this notification.
    # @return [Boolean] If the target subscribes the notification
    def subscribed?
      target.subscribes_to_notification?(key)
    end

    # Returns if the target subscribes this notification email.
    # @return [Boolean] If the target subscribes the notification
    def email_subscribed?(key)
      target.subscribes_to_notification_email?(key)
    end


    protected

      # Returns count of group members of the unopened notification.
      # This method is designed to cache group by query result to avoid N+1 call.
      # @api protected
      #
      # @return [Integer] Count of group members of the unopened notification
      def unopened_group_member_count
        # Cache group by query result to avoid N+1 call
        unopened_group_member_counts = target.notifications
                                             .unopened_index_group_members_only
                                             .group(:group_owner_id)
                                             .count
        unopened_group_member_counts[id] || 0
      end

      # Returns count of group members of the opened notification.
      # This method is designed to cache group by query result to avoid N+1 call.
      # @api protected
      #
      # @return [Integer] Count of group members of the opened notification
      def opened_group_member_count(limit = ActivityNotification.config.opened_index_limit)
        # Cache group by query result to avoid N+1 call
        opened_group_member_counts   = target.notifications
                                             .opened_index_group_members_only(limit)
                                             .group(:group_owner_id)
                                             .count
        opened_group_member_counts[id] || 0
      end

      # Returns count of group member notifiers of the unopened notification not including group owner notifier.
      # This method is designed to cache group by query result to avoid N+1 call.
      # @api protected
      #
      # @return [Integer] Count of group member notifiers of the unopened notification
      def unopened_group_member_notifier_count
        # Cache group by query result to avoid N+1 call
        unopened_group_member_notifier_counts = target.notifications
                                                      .unopened_index_group_members_only
                                                      .includes(:group_owner)
                                                      .where('group_owners_notifications.notifier_type = notifications.notifier_type')
                                                      .where.not('group_owners_notifications.notifier_id = notifications.notifier_id')
                                                      .references(:group_owner)
                                                      .group(:group_owner_id, :notifier_type)
                                                      .count('distinct notifications.notifier_id')
        unopened_group_member_notifier_counts[[id, notifier_type]] || 0
      end

      # Returns count of group member notifiers of the opened notification not including group owner notifier.
      # This method is designed to cache group by query result to avoid N+1 call.
      # @api protected
      #
      # @return [Integer] Count of group member notifiers of the opened notification
      def opened_group_member_notifier_count(limit = ActivityNotification.config.opened_index_limit)
        # Cache group by query result to avoid N+1 call
        opened_group_member_notifier_counts   = target.notifications
                                                      .opened_index_group_members_only(limit)
                                                      .includes(:group_owner)
                                                      .where('group_owners_notifications.notifier_type = notifications.notifier_type')
                                                      .where.not('group_owners_notifications.notifier_id = notifications.notifier_id')
                                                      .references(:group_owner)
                                                      .group(:group_owner_id, :notifier_type)
                                                      .count('distinct notifications.notifier_id')
        opened_group_member_notifier_counts[[id, notifier_type]] || 0
      end

      # Returns count of various members of the notification.
      # This method is designed to cache group by query result to avoid N+1 call.
      # @api protected
      #
      # @param [Symbol] opened_member_count_method_name Method name to count members of unopened index
      # @param [Symbol] unopened_member_count_method_name Method name to count members of opened index
      # @param [Integer] limit Limit to query for opened notifications
      # @return [Integer] Count of various members of the notification
      def meta_group_member_count(opened_member_count_method_name, unopened_member_count_method_name, limit)
        notification = group_member? ? group_owner : self
        notification.opened? ?
          notification.send(opened_member_count_method_name, limit) :
          notification.send(unopened_member_count_method_name)
      end

  end
end