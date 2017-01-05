module ActivityNotification
  # Defines API for subscription included in Subscription model.
  module SubscriptionApi
    extend ActiveSupport::Concern

    class_methods do
      # Returns key of optional_targets hash from symbol class name of the optional target implementation.
      # @param [String, Symbol] optional_target_name Class name of the optional target implementation (e.g. :amazon_sns, :slack)
      # @return [Symbol] Key of optional_targets hash
      def to_optional_target_key(optional_target_name)
        ("subscribing_to_" + optional_target_name.to_s).to_sym
      end

      # Returns subscribed_at parameter key of optional_targets hash from symbol class name of the optional target implementation.
      # @param [String, Symbol] optional_target_name Class name of the optional target implementation (e.g. :amazon_sns, :slack)
      # @return [Symbol] Subscribed_at parameter key of optional_targets hash
      def to_optional_target_subscribed_at_key(optional_target_name)
        ("subscribed_to_" + optional_target_name.to_s + "_at").to_sym
      end

      # Returns unsubscribed_at parameter key of optional_targets hash from symbol class name of the optional target implementation.
      # @param [String, Symbol] optional_target_name Class name of the optional target implementation (e.g. :amazon_sns, :slack)
      # @return [Symbol] Unsubscribed_at parameter key of optional_targets hash
      def to_optional_target_unsubscribed_at_key(optional_target_name)
        ("unsubscribed_to_" + optional_target_name.to_s + "_at").to_sym
      end
    end

    # Subscribes to the notification and notification email.
    #
    # @param [Hash] options Options for subscribing to the notification
    # @option options [DateTime] :subscribed_at           (Time.current) Time to set to subscribed_at and subscribed_to_email_at of the subscription record
    # @option options [Boolean]  :with_email_subscription (true)         If the subscriber also subscribes notification email
    # @option options [Boolean]  :with_optional_targets   (true)         If the subscriber also subscribes optional_targets
    # @return [Boolean] If successfully updated subscription instance
    def subscribe(options = {})
      subscribed_at = options[:subscribed_at] || Time.current
      with_email_subscription = options.has_key?(:with_email_subscription) ? options[:with_email_subscription] : true
      with_optional_targets   = options.has_key?(:with_optional_targets) ? options[:with_optional_targets] : true
      new_attributes = { subscribing: true, subscribed_at: subscribed_at, optional_targets: optional_targets }
      new_attributes = new_attributes.merge(subscribing_to_email: true, subscribed_to_email_at: subscribed_at) if with_email_subscription
      if with_optional_targets
        optional_target_names.each do |optional_target_name|
          new_attributes[:optional_targets] = new_attributes[:optional_targets].merge(
            Subscription.to_optional_target_key(optional_target_name) => true,
            Subscription.to_optional_target_subscribed_at_key(optional_target_name) => subscribed_at)
        end
      end
      update(new_attributes)
    end

    # Unsubscribes to the notification and notification email.
    #
    # @param [Hash] options Options for unsubscribing to the notification
    # @option options [DateTime] :unsubscribed_at (Time.current) Time to set to unsubscribed_at and unsubscribed_to_email_at of the subscription record
    # @return [Boolean] If successfully updated subscription instance
    def unsubscribe(options = {})
      unsubscribed_at = options[:unsubscribed_at] || Time.current
      new_attributes = { subscribing:          false, unsubscribed_at:          unsubscribed_at,
                         subscribing_to_email: false, unsubscribed_to_email_at: unsubscribed_at,
                         optional_targets: optional_targets }
      optional_target_names.each do |optional_target_name|
        new_attributes[:optional_targets] = new_attributes[:optional_targets].merge(
          Subscription.to_optional_target_key(optional_target_name) => false,
          Subscription.to_optional_target_unsubscribed_at_key(optional_target_name) => subscribed_at)
      end
      update(new_attributes)
    end

    # Subscribes to the notification email.
    #
    # @param [Hash] options Options for subscribing to the notification email
    # @option options [DateTime] :subscribed_to_email_at (Time.current) Time to set to subscribed_to_email_at of the subscription record
    # @return [Boolean] If successfully updated subscription instance
    def subscribe_to_email(options = {})
      subscribed_to_email_at = options[:subscribed_to_email_at] || Time.current
      update(subscribing_to_email: true, subscribed_to_email_at: subscribed_to_email_at)
    end

    # Unsubscribes to the notification email.
    #
    # @param [Hash] options Options for unsubscribing the notification email
    # @option options [DateTime] :subscribed_to_email_at (Time.current) Time to set to subscribed_to_email_at of the subscription record
    # @return [Boolean] If successfully updated subscription instance
    def unsubscribe_to_email(options = {})
      unsubscribed_to_email_at = options[:unsubscribed_to_email_at] || Time.current
      update(subscribing_to_email: false, unsubscribed_to_email_at: unsubscribed_to_email_at)
    end

    # Returns if the target subscribes to the specified optional target.
    #
    # @param [Symbol]  optional_target_name Symbol class name of the optional target implementation (e.g. :amazon_sns, :slack)
    # @param [Boolean] subscribe_as_default Default subscription value to use when the subscription record does not configured
    # @return [Boolean] If the target subscribes to the specified optional target
    def subscribing_to_optional_target?(optional_target_name, subscribe_as_default = ActivityNotification.config.subscribe_as_default)
      optional_target_key = Subscription.to_optional_target_key(optional_target_name)
      subscribe_as_default ?
        !optional_targets.has_key?(optional_target_key) || optional_targets[optional_target_key] :
         optional_targets.has_key?(optional_target_key) && optional_targets[optional_target_key]
    end

    # Subscribes to the specified optional target.
    #
    # @param [String, Symbol]  optional_target_name Symbol class name of the optional target implementation (e.g. :amazon_sns, :slack)
    # @param [Hash]            options              Options for unsubscribing to the specified optional target
    # @option options [DateTime] :subscribed_at (Time.current) Time to set to subscribed_[optional_target_name]_at in optional_targets hash of the subscription record
    # @return [Boolean] If successfully updated subscription instance
    def subscribe_to_optional_target(optional_target_name, options = {})
      subscribed_at = options[:subscribed_at] || Time.current
      update(optional_targets: optional_targets.merge(
        Subscription.to_optional_target_key(optional_target_name) => true,
        Subscription.to_optional_target_subscribed_at_key(optional_target_name) => subscribed_at)
      )
    end

    # Unsubscribes to the specified optional target.
    #
    # @param [String, Symbol] optional_target_name Class name of the optional target implementation (e.g. :amazon_sns, :slack)
    # @param [Hash]           options              Options for unsubscribing to the specified optional target
    # @option options [DateTime] :unsubscribed_at (Time.current) Time to set to unsubscribed_[optional_target_name]_at in optional_targets hash of the subscription record
    # @return [Boolean] If successfully updated subscription instance
    def unsubscribe_to_optional_target(optional_target_name, options = {})
      unsubscribed_at = options[:unsubscribed_at] || Time.current
      update(optional_targets: optional_targets.merge(
        Subscription.to_optional_target_key(optional_target_name) => false,
        Subscription.to_optional_target_unsubscribed_at_key(optional_target_name) => unsubscribed_at)
      )
    end

    # Returns optional_target names of the subscription from optional_targets field.
    # @return [Array<Symbol>] Array of optional target names
    def optional_target_names
      optional_targets.keys.select { |key| key.to_s.start_with?("subscribing_to_") }.map { |key| key.slice(15..-1) }
    end
  end
end