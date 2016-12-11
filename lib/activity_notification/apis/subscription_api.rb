module ActivityNotification
  # Defines API for subscription included in Subscription model.
  module SubscriptionApi
    extend ActiveSupport::Concern

    # Subscribes to the notification and notification email.
    #
    # @param [Hash] options Options for subscribing notification
    # @option options [DateTime] :subscribed_at           (DateTime.now) Time to set to subscribed_at and subscribed_to_email_at of the subscription record
    # @option options [Boolean]  :with_email_subscription (true)         If it also subscribes notification email
    # @return [Boolean] If successfully updated subscription instance
    def subscribe(options = {})
      subscribed_at = options[:subscribed_at] || DateTime.now
      with_email_subscription = options.has_key?(:with_email_subscription) ? options[:with_email_subscription] : true
      with_email_subscription ?
        update(subscribing: true, subscribing_to_email: true, subscribed_at: subscribed_at, subscribed_to_email_at: subscribed_at) :
        update(subscribing: true, subscribed_at: subscribed_at)
    end

    # Unsubscribes to the notification and notification email.
    #
    # @param [Hash] options Options for unsubscribing notification
    # @option options [DateTime] :unsubscribed_at (DateTime.now) Time to set to unsubscribed_at and unsubscribed_to_email_at of the subscription record
    # @return [Boolean] If successfully updated subscription instance
    def unsubscribe(options = {})
      unsubscribed_at = options[:unsubscribed_at] || DateTime.now
      update(subscribing: false, subscribing_to_email: false, unsubscribed_at: unsubscribed_at, unsubscribed_to_email_at: unsubscribed_at)
    end

    # Subscribes to the notification email.
    #
    # @param [Hash] options Options for subscribing notification email
    # @option options [DateTime] :subscribed_to_email_at (DateTime.now) Time to set to subscribed_to_email_at of the subscription record
    # @return [Boolean] If successfully updated subscription instance
    def subscribe_to_email(options = {})
      subscribed_to_email_at = options[:subscribed_to_email_at] || DateTime.now
      update(subscribing_to_email: true, subscribed_to_email_at: subscribed_to_email_at)
    end

    # Unsubscribes to the notification email.
    #
    # @param [Hash] options Options for unsubscribing notification email
    # @option options [DateTime] :subscribed_to_email_at (DateTime.now) Time to set to subscribed_to_email_at of the subscription record
    # @return [Boolean] If successfully updated subscription instance
    def unsubscribe_to_email(options = {})
      unsubscribed_to_email_at = options[:unsubscribed_to_email_at] || DateTime.now
      update(subscribing_to_email: false, unsubscribed_to_email_at: unsubscribed_to_email_at)
    end

  end
end