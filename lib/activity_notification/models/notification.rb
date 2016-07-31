module ActivityNotification
  class Notification < ActiveRecord::Base
    include Renderable
    include Common
    include NotificationApi
    self.table_name = ActivityNotification.config.table_name
  
    belongs_to :target,        polymorphic: true
    belongs_to :notifiable,    polymorphic: true
    belongs_to :group,         polymorphic: true
    belongs_to :group_owner,   class_name: :Notification
    has_many   :group_members,
      class_name: "::ActivityNotification::Notification",
      foreign_key: :group_owner_id
    belongs_to :notifier,      polymorphic: true

    # Serialize parameters Hash
    serialize  :parameters, Hash

    validates  :target,        presence: true
    validates  :notifiable,    presence: true
    validates  :key,           presence: true

    scope :group_owners_only,                 ->        { where(group_owner_id: nil) }
    scope :group_members_only,                ->        { where.not(group_owner_id: nil) }
    scope :unopened_only,                     ->        { where(opened_at: nil) }
    scope :unopened_index,                    ->        { unopened_only.group_owners_only.latest_order }
    scope :opened_only!,                      ->        { where.not(opened_at: nil) }
    scope :opened_only,                       ->(limit) { opened_only!.limit(limit) }
    scope :opened_index,                      ->(limit) { opened_only(limit).group_owners_only.latest_order }
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

    scope :latest_order,                      ->        { order(created_at: :desc) }
    scope :earliest_order,                    ->        { order(created_at: :asc) }
    scope :latest,                            ->        { latest_order.first }
    scope :earliest,                          ->        { earliest_order.first }
  end
end
