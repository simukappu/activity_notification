module ActivityNotification
  module NotificationApi
    extend ActiveSupport::Concern

    # Define store_notification as private clas method
    included do
      private_class_method :store_notification
    end

    # For notification API
    class_methods do
      def notify(target_type, notifiable, options = {})
        targets = notifiable.notification_targets(target_type, options[:key])
        unless targets.blank?
          notify_all(targets, notifiable, options)
        end
      end
    
      def notify_all(targets, notifiable, options = {})
        Array(targets).map { |target| notify_to(target, notifiable, options) }
      end
    
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
  
      # Open all notifications of specified target
      def open_all_of(target, opened_at = nil)
        opened_at = DateTime.now if opened_at.blank?
        where(target: target, opened_at: nil).update_all(opened_at: opened_at)
      end
  
      #TODO description
      # Call from controllers or views to avoid N+1
      def group_member_exists?(notifications)
        notifications.present? && where(group_owner_id: notifications.pluck(:id)).exists?
      end
    
      def available_options
        [:key, :group, :parameters, :notifier, :send_email, :send_later].freeze
      end

      # Private class methods
  
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


    # Public instance methods

    def send_notification_email(send_later = true)
      if send_later
        Mailer.send_notification_email(self).deliver_later
      else
        Mailer.send_notification_email(self).deliver_now
      end
    end

    def open!(opened_at = nil)
      opened_at = DateTime.now if opened_at.blank?
      update(opened_at: opened_at)
      group_members.update_all(opened_at: opened_at) + 1
    end

    def unopened?
      !opened?
    end

    def opened?
      opened_at.present?
    end

    def group_owner?
      group_owner_id.blank?
    end

    def group_member?
      group_owner_id.present?
    end
  
    # Cache group-by query result to avoid N+1 call
    def group_member_exists?(limit = ActivityNotification.config.opened_limit)
      group_member_count(limit) > 0
    end

    # Cache group-by query result to avoid N+1 call
    def group_member_count(limit = ActivityNotification.config.opened_limit)
      notification = group_member? ? group_owner : self
      notification.opened? ?
        notification.opened_group_member_count(limit) :
        notification.unopened_group_member_count
    end

    def notifiable_path
      notifiable.notifiable_path(target_type, key)
    end


    # Protected instance methods
    protected

      def unopened_group_member_count
        # Cache group-by query result to avoid N+1 call
        unopened_group_member_counts = target.notifications
                                             .unopened_index_group_members_only
                                             .group(:group_owner_id)
                                             .count
        unopened_group_member_counts[id] || 0
      end
    
      def opened_group_member_count(limit = ActivityNotification.config.opened_limit)
        # Cache group-by query result to avoid N+1 call
        opened_group_member_counts   = target.notifications
                                             .opened_index_group_members_only(limit)
                                             .group(:group_owner_id)
                                             .count
        opened_group_member_counts[id] || 0
      end

  end
end