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
      # @option options [String]  :key        (notifiable.default_notification_key) Notification key
      # @option options [Object]  :group      (nil)                                 Group unit of the notifications
      # @option options [Object]  :notifier   (nil)                                 Notifier of the notifications
      # @option options [Hash]    :parameters ({})                                  Additional parameters of the notifications
      # @option options [Boolean] :send_email (true)                                If it sends notification email
      # @option options [Boolean] :send_later (true)                                If it sends notification email asynchronously
      # @return [Array] Array of generated notifications
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
      # @param [Array] targets Targets to send notifications
      # @param [Object] notifiable Notifiable instance
      # @param [Hash] options Options for notifications
      # @option options [String]  :key        (notifiable.default_notification_key) Notification key
      # @option options [Object]  :group      (nil)                                 Group unit of the notifications
      # @option options [Object]  :notifier   (nil)                                 Notifier of the notifications
      # @option options [Hash]    :parameters ({})                                  Additional parameters of the notifications
      # @option options [Boolean] :send_email (true)                                Whether it sends notification email
      # @option options [Boolean] :send_later (true)                                Whether it sends notification email asynchronously
      # @return [Array] Array of generated notifications
      def notify_all(targets, notifiable, options = {})
        Array(targets).map { |target| notify_to(target, notifiable, options) }
      end

      # Generates notifications to one target.
      #
      # @example Notify to one user
      #   ActivityNotification::Notification.notify_to @comment.auther, @comment
      #
      # @param [Object] target Target to send notifications
      # @param [Object] notifiable Notifiable instance
      # @param [Hash] options Options for notifications
      # @option options [String]  :key        (notifiable.default_notification_key) Notification key
      # @option options [Object]  :group      (nil)                                 Group unit of the notifications
      # @option options [Object]  :notifier   (nil)                                 Notifier of the notifications
      # @option options [Hash]    :parameters ({})                                  Additional parameters of the notifications
      # @option options [Boolean] :send_email (true)                                Whether it sends notification email
      # @option options [Boolean] :send_later (true)                                Whether it sends notification email asynchronously
      # @return [Notification] Generated notification instance
      def notify_to(target, notifiable, options = {})
        send_email = options.has_key?(:send_email) ? options[:send_email] : true
        send_later = options.has_key?(:send_later) ? options[:send_later] : true
        # Store notification
        notification = store_notification(target, notifiable, options)
        # Send notification email
        notification.send_notification_email(send_later) if send_email
        # Return created notification
        notification
      end

      # Opens all notifications of the target.
      #
      # @param [Object] target Target of the notifications to open
      # @param [Hash] options Options for opening notifications
      # @option options [DateTime] :opened_at (DateTime.now) Time to set to opened_at of the notification record
      # @return [Integer] Number of opened notification records
      # @todo Add filter option
      def open_all_of(target, options = {})
        opened_at = options[:opened_at] || DateTime.now
        where(target: target, opened_at: nil).update_all(opened_at: opened_at)
      end
  
      # Returns if group member of the notifications exists.
      # This method is designed to be called from controllers or views to avoid N+1.
      #
      # @param [Array | ActiveRecord_AssociationRelation] notifications Array or database query of the notifications to test member exists
      # @return [Boolean] If group member of the notifications exists
      def group_member_exists?(notifications)
        notifications.present? && where(group_owner_id: notifications.map(&:id)).exists?
      end

      # Returns available options for kinds of notify methods.
      #
      # @return [Array] Available options for kinds of notify methods
      def available_options
        [:key, :group, :parameters, :notifier, :send_email, :send_later].freeze
      end

      # Stores notifications to datastore
      # @api private
      def store_notification(target, notifiable, options = {})
        target_type = target.to_class_name
        key         = options[:key]        || notifiable.default_notification_key
        group       = options[:group]      || notifiable.notification_group(target_type, key)
        notifier    = options[:notifier]   || notifiable.notifier(target_type, key)
        parameters  = options[:parameters] || {}
        parameters.merge!(options.except(*available_options))
        parameters.merge!(notifiable.notification_parameters(target_type, key))

        # Bundle notification group by target, notifiable_type, group and key
        # Defferent notifiable.id can be made in a same group
        group_owner = where(target: target, notifiable_type: notifiable.to_class_name, key: key, group: group)
                     .where(group_owner_id: nil, opened_at: nil).earliest
        if group.present? and group_owner.present?
          create(target: target, notifiable: notifiable, key: key, group: group, group_owner: group_owner, parameters: parameters, notifier: notifier)
        else
          create(target: target, notifiable: notifiable, key: key, group: group, parameters: parameters, notifier: notifier)
        end
      end
    end


    # Sends notification email to the target.
    #
    # @param [Boolean] send_later If it sends notification email asynchronously
    # @return [Mail::Message, ActionMailer::DeliveryJob] Email message or its delivery job
    def send_notification_email(send_later = true)
      if send_later
        Mailer.send_notification_email(self).deliver_later
      else
        Mailer.send_notification_email(self).deliver_now
      end
    end

    # Opens the notification.
    #
    # @param [Hash] options Options for opening notifications
    # @option options [DateTime] :opened_at (DateTime.now) Time to set to opened_at of the notification record
    # @option options [Boolean] :with_members (true) If it opens notifications including group members
    # @return [Integer] Number of opened notification records
    def open!(options = {})
      opened_at = options[:opened_at] || DateTime.now
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
    def group_member_exists?(limit = ActivityNotification.config.opened_limit)
      group_member_count(limit) > 0
    end

    # Returns count of group members of the notification.
    # This method is designed to cache group by query result to avoid N+1 call.
    #
    # @param [Integer] limit Limit to query for opened notifications
    # @return [Integer] Count of group members of the notification
    def group_member_count(limit = ActivityNotification.config.opened_limit)
      notification = group_member? ? group_owner : self
      notification.opened? ?
        notification.opened_group_member_count(limit) :
        notification.unopened_group_member_count
    end

    # Returns notifiable_path to move after opening notification with notifiable.notifiable_path.
    #
    # @return [String] Notifiable path URL to move after opening notification
    def notifiable_path
      notifiable.notifiable_path(target_type, key)
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
      def opened_group_member_count(limit = ActivityNotification.config.opened_limit)
        # Cache group by query result to avoid N+1 call
        opened_group_member_counts   = target.notifications
                                             .opened_index_group_members_only(limit)
                                             .group(:group_owner_id)
                                             .count
        opened_group_member_counts[id] || 0
      end

  end
end