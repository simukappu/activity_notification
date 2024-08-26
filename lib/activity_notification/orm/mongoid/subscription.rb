require 'mongoid'
require 'activity_notification/apis/subscription_api'

module ActivityNotification
  module ORM
    module Mongoid
      # Subscription model implementation generated by ActivityNotification.
      class Subscription
        include ::Mongoid::Document
        include ::Mongoid::Timestamps
        include ::Mongoid::Attributes::Dynamic
        include Association
        include SubscriptionApi
        store_in collection: ActivityNotification.config.subscription_table_name

        # Belongs to target instance of this subscription as polymorphic association.
        # @scope instance
        # @return [Object] Target instance of this subscription
        belongs_to_polymorphic_xdb_record :target

        field :key,                       type: String
        field :subscribing,               type: Boolean, default: ActivityNotification.config.subscribe_as_default
        field :subscribing_to_email,      type: Boolean, default: ActivityNotification.config.subscribe_to_email_as_default
        field :subscribed_at,             type: DateTime
        field :unsubscribed_at,           type: DateTime
        field :subscribed_to_email_at,    type: DateTime
        field :unsubscribed_to_email_at,  type: DateTime
        field :optional_targets,          type: Hash,    default: {}

        validates  :target,               presence: true
        validates  :key,                  presence: true, uniqueness: { scope: [:target_type, :target_id] }
        validates_inclusion_of :subscribing,          in: [true, false]
        validates_inclusion_of :subscribing_to_email, in: [true, false]
        validate   :subscribing_to_email_cannot_be_true_when_subscribing_is_false
        validates  :subscribed_at,            presence: true, if:     :subscribing
        validates  :unsubscribed_at,          presence: true, unless: :subscribing
        validates  :subscribed_to_email_at,   presence: true, if:     :subscribing_to_email
        validates  :unsubscribed_to_email_at, presence: true, unless: :subscribing_to_email
        validate   :subscribing_to_optional_target_cannot_be_true_when_subscribing_is_false

        # Selects filtered subscriptions by type of the object.
        # Filtering with ActivityNotification::Subscription is defined as default scope.
        # @return [Mongoid::Criteria<Subscription>] Database query of filtered subscriptions
        default_scope -> { where(_type: "ActivityNotification::Subscription") }

        # Selects filtered subscriptions by target instance.
        #   ActivityNotification::Subscription.filtered_by_target(@user)
        # is the same as
        #   @user.notification_subscriptions
        # @scope class
        # @param [Object] target Target instance for filter
        # @return [Mongoid::Criteria<Subscription>] Database query of filtered subscriptions
        scope :filtered_by_target,  ->(target) { filtered_by_association("target", target) }

        # Includes target instance with query for subscriptions.
        # @return [Mongoid::Criteria<Subscription>] Database query of subscriptions with target
        scope :with_target,               -> { }

        # Dummy reload method for test of subscriptions.
        scope :reload,                    -> { }

        # Selects unique keys from query for subscriptions.
        # @return [Array<String>] Array of subscription unique keys
        def self.uniq_keys
          # distinct method cannot keep original sort
          # distinct(:key)
          pluck(:key).uniq
        end

      end
    end
  end
end
