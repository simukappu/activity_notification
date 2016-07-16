module ActivityNotification
  class Notification < ActiveRecord::Base
    include Renderable
    include Common
    self.table_name = ActivityNotification.config.table_name
  
    belongs_to :target,        polymorphic: true
    belongs_to :notifiable,    polymorphic: true
    belongs_to :group,         polymorphic: true
    belongs_to :group_owner,   class_name: :Notification
    belongs_to :notifier,      polymorphic: true
    has_many   :group_members,
      class_name: "::ActivityNotification::Notification",
      foreign_key: :group_owner_id

    # Serialize parameters Hash
    serialize  :parameters, Hash

    validates  :target,        presence: true
    validates  :notifiable,    presence: true
    validates  :key,           presence: true

    scope :group_owners_only,                 ->        { where(group_owner_id: nil) }
    scope :group_members_only,                ->        { where.not(group_owner_id: nil) }
    scope :unopened_only,                     ->        { where(opened_at: nil) }
    scope :unopened_index,                    ->        { unopened_only.group_owners_only.earliest_order }
    scope :opened_only!,                      ->        { where.not(opened_at: nil) }
    scope :opened_only,                       ->(limit) { opened_only!.limit(limit) }
    scope :opened_index,                      ->(limit) { opened_only(limit).group_owners_only.earliest_order }
    scope :unopened_index_group_members_only, ->        { where(group_owner_id: unopened_index.pluck(:id)) }
    scope :opened_index_group_members_only,   ->(limit) { where(group_owner_id: opened_index(limit).pluck(:id)) }

    scope :filtered_by_target,   ->(target)             { where(target: target) }
    scope :filtered_by_instance, ->(notifiable)         { where(notifiable: notifiable) }
    scope :filtered_by_type,     ->(notifiable_type)    { where(notifiable_type: notifiable_type) }
    scope :filtered_by_group,    ->(group)              { where(group: group) }
    scope :filtered_by_key,      ->(key)                { where(key: key) }

    scope :with_target,                       ->        { includes(:target) }
    scope :with_notifiable,                   ->        { includes(:notifiable) }
    scope :with_group,                        ->        { includes(:group) }
    scope :with_notifier,                     ->        { includes(:notifier) }

    scope :earliest_order,                    ->        { order(created_at: :desc) }
    scope :latest_order,                      ->        { order(created_at: :asc) }
    scope :earliest,                          ->        { earliest_order.first }
    scope :latest,                            ->        { latest_order.first }

  
    # Public class methods

    # API for notification
  
    def self.notify(target_type, notifiable, options = {})
      targets = notifiable.notification_targets(target_type, options[:key])
      unless targets.blank?
        notify_all(targets, notifiable, options)
      end
    end
  
    def self.notify_all(targets, notifiable, options = {})
      targets.each do |target|
        notify_to(target, notifiable, options)
      end
    end
  
    def self.notify_to(target, notifiable, options = {})
      send_email = options.has_key?(:send_email) ? options[:send_email] : true
      send_later = options.has_key?(:send_later) ? options[:send_later] : true
      # Store notification
      notification = store_notification(target, notifiable, options)
      # Send notification email
      notification.send_notification_email(send_later) if send_email
    end


    # Open all notifications of specified target
    def self.open_all_of(target, opened_at = nil)
      opened_at = DateTime.now if opened_at.blank?
      Notification.where(target: target, opened_at: nil).update_all(opened_at: opened_at)
    end

    #TODO description
    # Call from controllers or views to avoid N+1
    def self.group_member_exists?(notifications)
      Notification.where(group_owner_id: notifications.pluck(:id)).exists?
    end
  
    def self.available_options
      [:key, :group, :parameters, :notifier, :send_email, :send_later].freeze
    end

    # Public instance methods
  
    def send_notification_email(send_later = true)
      if send_later
        # TODO replace with deliver_later
        Mailer.delay.send_notification_email(self)
      else
        Mailer.send_notification_email(self).deliver_now
      end
    end

    def open!(opened_at = nil)
      opened_at = DateTime.now if opened_at.blank?
      update(opened_at: opened_at)
      group_members.update_all(opened_at: opened_at)
    end

    def unopened?
      !opened?
    end

    def opened?
      opened_at.present?
    end

    def group_owner?
      group_owner_id.present?
    end
  
    # Cache group-by query result to avoid N+1 call
    def group_member_exists?(limit = ActivityNotification.config.opened_limit)
      group_member_count(limit) > 0
    end

    # Cache group-by query result to avoid N+1 call
    def group_member_count(limit = ActivityNotification.config.opened_limit)
      notification = group_owner? ? group_owner : self
      notification.opened? ?
        opened_group_member_count(limit) :
        unopened_group_member_count
    end

    def notifiale_path
      notifiable.notifiable_path(target_type)
    end


    # Private class methods

    def self.store_notification(target, notifiable, options = {})
      target_type = target.to_class_name
      key         = options[:key]        || "#{notifiable.to_resource_name}.default"
      group       = options[:group]      || notifiable.notification_group(target_type, key)
      notifier    = options[:notifier]   || notifiable.notifier(target_type, key)
      parameters  = options[:parameters] || {}
      parameters.merge!(options.except(available_options))
      parameters.merge!(notifiable.notification_parameters(target_type, key))

      # Bundle notification group by target, notifiable_type, group and key
      # Defferent notifiable.id can be made in a same group
      group_owner = Notification.where(target: target, notifiable_type: notifiable.to_class_name, key: key, group: group)
                                .where(group_owner_id: nil, opened_at: nil).earliest
      if group.present? and group_owner.present?
        create(target: target, notifiable: notifiable, key: key, group: group, group_owner: group_owner, parameters: parameters, notifier: notifier)
      else
        create(target: target, notifiable: notifiable, key: key, group: group, parameters: parameters, notifier: notifier)
      end
    end

    private_class_method :store_notification

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
