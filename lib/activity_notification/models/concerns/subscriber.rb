module ActivityNotification
  # Subscriber implementation included in target model to manage subscriptions, like users or administrators.
  module Subscriber
    extend ActiveSupport::Concern

    included do
      include Association

      # Has many subscription instances of this target.
      # @scope instance
      # @return [Array<Subscription>, Mongoid::Criteria<Subscription>] Array or database query of subscriptions of this target
      has_many_records :subscriptions,
        class_name: "::ActivityNotification::Subscription",
        as: :target,
        dependent: :delete_all
    end

    class_methods do
      # Checks if the model includes subscriber and subscriber methods are available.
      # Also checks if the model includes target and target methods are available, then return true.
      # @return [Boolean] If the model includes target and subscriber are available
      def available_as_subscriber?
        available_as_target?
      end
    end


    # Gets subscription of the target and notification key.
    #
    # @param [String] key Key of the notification for subscription
    # @param [Object] notifiable Optional notifiable instance for instance-level subscription lookup
    # @return [Subscription] Configured subscription instance
    def find_subscription(key, notifiable: nil)
      if notifiable
        if ActivityNotification.config.orm == :dynamoid
          # :nocov:
          delimiter = ActivityNotification.config.composite_key_delimiter
          subscriptions.where(key: key, notifiable_key: "#{notifiable.class.name}#{delimiter}#{notifiable.id}").first
          # :nocov:
        else
          # :nocov:
          subscriptions.where(key: key, notifiable_type: notifiable.class.name, notifiable_id: notifiable.id).first
          # :nocov:
        end
      else
        if ActivityNotification.config.orm == :dynamoid
          # :nocov:
          subscriptions.where(key: key).select { |s| s.notifiable_type.nil? }.first
          # :nocov:
        else
          # :nocov:
          subscriptions.where(key: key, notifiable_type: nil).first
          # :nocov:
        end
      end
    end

    # Gets subscription of the target and notification key.
    #
    # @param [String] key                 Key of the notification for subscription
    # @param [Hash] subscription_params Parameters to create subscription record
    # @return [Subscription] Found or created subscription instance
    def find_or_create_subscription(key, subscription_params = {})
      notifiable = subscription_params.delete(:notifiable)
      subscription = find_subscription(key, notifiable: notifiable)
      merge_params = { key: key }
      if notifiable
        merge_params[:notifiable_type] = notifiable.class.name
        merge_params[:notifiable_id]   = notifiable.id
      end
      subscription || create_subscription(subscription_params.merge(merge_params))
    end

    # Creates new subscription of the target.
    #
    # @param [Hash] subscription_params Parameters to create subscription record
    # @raise [ActivityNotification::RecordInvalidError] Failed to save subscription due to model validation
    # @return [Subscription] Created subscription instance
    def create_subscription(subscription_params = {})
      subscription = build_subscription(subscription_params)
      raise RecordInvalidError, subscription.errors.full_messages.first unless subscription.save
      subscription
    end

    # Builds new subscription of the target.
    #
    # @param [Hash] subscription_params Parameters to build subscription record
    # @return [Subscription] Built subscription instance
    def build_subscription(subscription_params = {})
      created_at = Time.current
      if subscription_params[:subscribing] == false && subscription_params[:subscribing_to_email].nil?
        subscription_params[:subscribing_to_email] = subscription_params[:subscribing]
      elsif subscription_params[:subscribing_to_email].nil?
        subscription_params[:subscribing_to_email] = ActivityNotification.config.subscribe_to_email_as_default
      end
      # :nocov:
      # Convert notifiable_type/notifiable_id to notifiable_key for Dynamoid
      if ActivityNotification.config.orm == :dynamoid && subscription_params[:notifiable_type].present? && subscription_params[:notifiable_id].present?
        delimiter = ActivityNotification.config.composite_key_delimiter
        subscription_params[:notifiable_key] = "#{subscription_params.delete(:notifiable_type)}#{delimiter}#{subscription_params.delete(:notifiable_id)}"
      end
      # :nocov:
      subscription = Subscription.new(subscription_params)
      subscription.assign_attributes(target: self)
      subscription.subscribing? ?
        subscription.assign_attributes(subscribing: true, subscribed_at: created_at) :
        subscription.assign_attributes(subscribing: false, unsubscribed_at: created_at)
      subscription.subscribing_to_email? ?
        subscription.assign_attributes(subscribing_to_email: true, subscribed_to_email_at: created_at) :
        subscription.assign_attributes(subscribing_to_email: false, unsubscribed_to_email_at: created_at)
      subscription.optional_targets = (subscription.optional_targets || {}).with_indifferent_access
      optional_targets = {}.with_indifferent_access
      subscription.optional_target_names.each do |optional_target_name|
        optional_targets = subscription.subscribing_to_optional_target?(optional_target_name) ?
          optional_targets.merge(
            Subscription.to_optional_target_key(optional_target_name) => true,
            Subscription.to_optional_target_subscribed_at_key(optional_target_name) => Subscription.convert_time_as_hash(created_at)
          ) :
          optional_targets.merge(
            Subscription.to_optional_target_key(optional_target_name) => false,
            Subscription.to_optional_target_unsubscribed_at_key(optional_target_name) => Subscription.convert_time_as_hash(created_at)
          )
      end
      subscription.assign_attributes(optional_targets: optional_targets)
      subscription
    end

    # Gets configured subscription index of the target.
    #
    # @example Get configured subscription index of the @user
    #   @subscriptions = @user.subscription_index
    #
    # @param [Hash] options Options for subscription index
    # @option options [Integer]    :limit                  (nil)   Limit to query for subscriptions
    # @option options [Boolean]    :reverse                (false) If subscription index will be ordered as earliest first
    # @option options [String]     :filtered_by_key        (nil)   Key of the notification for filter
    # @option options [Array|Hash] :custom_filter          (nil)   Custom subscription filter (e.g. ["created_at >= ?", time.hour.ago])
    # @option options [Boolean]    :with_target            (false) If it includes target with subscriptions
    # @return [Array<Notificaion>] Configured subscription index of the target
    def subscription_index(options = {})
      target_index = subscriptions.filtered_by_options(options)
      target_index = options[:reverse] ? target_index.earliest_order : target_index.latest_order
      target_index = target_index.with_target if options[:with_target]
      options[:limit].present? ? target_index.limit(options[:limit]).to_a : target_index.to_a
    end

    # Gets received notification keys of the target.
    #
    # @example Get unconfigured notification keys of the @user
    #   @notification_keys = @user.notification_keys(filter: :unconfigured)
    #
    # @param [Hash] options Options for unconfigured notification keys
    # @option options [Integer]       :limit                  (nil)   Limit to query for subscriptions
    # @option options [Boolean]       :reverse                (false) If notification keys will be ordered as earliest first
    # @option options [Symbol|String] :filter                 (nil)   Filter option to load notification keys (Nothing as all, 'configured' with configured subscriptions or 'unconfigured' without subscriptions)
    # @option options [String]        :filtered_by_key        (nil)   Key of the notification for filter
    # @option options [Array|Hash]    :custom_filter          (nil)   Custom subscription filter (e.g. ["created_at >= ?", time.hour.ago])
    # @return [Array<Notificaion>] Unconfigured notification keys of the target
    def notification_keys(options = {})
      subscription_keys    = subscriptions.uniq_keys
      target_notifications = notifications.filtered_by_options(options.select { |k, _| [:filtered_by_key, :custom_filter].include?(k) })
      target_notifications = options[:reverse] ? target_notifications.earliest_order : target_notifications.latest_order
      target_notifications = options[:limit].present? ? target_notifications.limit(options[:limit] + subscription_keys.size) : target_notifications
      notification_keys    = target_notifications.uniq_keys
      notification_keys    =
        case options[:filter]
        when :configured, 'configured'
          notification_keys & subscription_keys
        when :unconfigured, 'unconfigured'
          notification_keys - subscription_keys
        else
          notification_keys
        end
      options[:limit].present? ? notification_keys.take(options[:limit]) : notification_keys
    end

    protected

      # Returns if the target subscribes to the notification.
      # This method can be overridden.
      # @api protected
      #
      # @param [String]  key                  Key of the notification
      # @param [Boolean] subscribe_as_default Default subscription value to use when the subscription record does not configured
      # @return [Boolean] If the target subscribes to the notification
      def _subscribes_to_notification?(key, subscribe_as_default = ActivityNotification.config.subscribe_as_default)
        subscription = _find_key_level_subscription(key)
        evaluate_subscription(subscription, :subscribing?, subscribe_as_default)
      end

      # Returns if the target subscribes to the notification for a specific notifiable instance.
      # @api protected
      #
      # @param [String]  key        Key of the notification
      # @param [Object]  notifiable Notifiable instance to check subscription for
      # @return [Boolean] If the target has an active instance-level subscription for this notifiable
      def _subscribes_to_notification_for_instance?(key, notifiable)
        instance_sub = find_subscription(key, notifiable: notifiable)
        instance_sub.present? && instance_sub.subscribing?
      end

      # Returns if the target subscribes to the notification email.
      # This method can be overridden.
      # @api protected
      #
      # @param [String]  key                  Key of the notification
      # @param [Boolean] subscribe_as_default Default subscription value to use when the subscription record does not configured
      # @return [Boolean] If the target subscribes to the notification
      def _subscribes_to_notification_email?(key, subscribe_as_default = ActivityNotification.config.subscribe_to_email_as_default)
        subscription = _find_key_level_subscription(key)
        evaluate_subscription(subscription, :subscribing_to_email?, subscribe_as_default)
      end
      alias_method :_subscribes_to_email?, :_subscribes_to_notification_email?

      # Returns if the target subscribes to the specified optional target.
      # This method can be overridden.
      # @api protected
      #
      # @param [String]         key                  Key of the notification
      # @param [String, Symbol] optional_target_name Class name of the optional target implementation (e.g. :amazon_sns, :slack)
      # @param [Boolean]        subscribe_as_default Default subscription value to use when the subscription record does not configured
      # @return [Boolean] If the target subscribes to the specified optional target
      def _subscribes_to_optional_target?(key, optional_target_name, subscribe_as_default = ActivityNotification.config.subscribe_to_optional_targets_as_default)
        subscription = _find_key_level_subscription(key)
        _subscribes_to_notification?(key, subscribe_as_default) &&
          evaluate_subscription(subscription, :subscribing_to_optional_target?, subscribe_as_default, optional_target_name, subscribe_as_default)
      end

    private

      # Finds a key-level subscription (where notifiable is nil) for the given key.
      # @api private
      # @param [String] key Key of the notification
      # @return [Subscription, nil] Key-level subscription record or nil
      def _find_key_level_subscription(key)
        find_subscription(key, notifiable: nil)
      end

      # Returns if the target subscribes.
      # @api private
      # @param [Boolean] record  Subscription record
      # @param [Symbol]  field   Evaluating subscription field or method of the record
      # @param [Boolean] default Default subscription value to use when the subscription record does not configured
      # @param [Array]   args    Arguments of evaluating subscription method
      # @return [Boolean] If the target subscribes
      def evaluate_subscription(record, field, default, *args)
        default ? record.blank? || record.send(field, *args) : record.present? && record.send(field, *args)
      end

  end
end
