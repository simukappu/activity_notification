require "active_support/core_ext/object/try"
require "active_support/core_ext/hash/slice"

module ActionDispatch::Routing
  # Extended ActionDispatch::Routing::Mapper implementation to add routing method of ActivityNotification.
  class Mapper
    include ActivityNotification::PolymorphicHelpers

    # Includes notify_to method for routes, which is responsible to generate all necessary routes for activity_notification.
    #
    # When you have an User model configured as a target (e.g. defined acts_as_target),
    # you can create as follows in your routes:
    #   notify_to :users
    # This method creates the needed routes:
    #   # Notification routes
    #     user_notifications          GET    /users/:user_id/notifications(.:format)
    #       { controller:"activity_notification/notifications", action:"index", target_type:"users" }
    #     user_notification           GET    /users/:user_id/notifications/:id(.:format)
    #       { controller:"activity_notification/notifications", action:"show", target_type:"users" }
    #     user_notification           DELETE /users/:user_id/notifications/:id(.:format)
    #       { controller:"activity_notification/notifications", action:"destroy", target_type:"users" }
    #     open_all_user_notifications POST   /users/:user_id/notifications/open_all(.:format)
    #       { controller:"activity_notification/notifications", action:"open_all", target_type:"users" }
    #     move_user_notification      POST   /users/:user_id/notifications/:id/move(.:format)
    #       { controller:"activity_notification/notifications", action:"move", target_type:"users" }
    #     open_user_notification      POST   /users/:user_id/notifications/:id/open(.:format)
    #       { controller:"activity_notification/notifications", action:"open", target_type:"users" }
    #
    # When you use devise authentication and you want make notification targets assciated with devise,
    # you can create as follows in your routes:
    #   notify_to :users, with_devise: :users
    # This with_devise option creates the needed routes assciated with devise authentication:
    #   # Notification with devise routes
    #     user_notifications          GET    /users/:user_id/notifications(.:format)
    #       { controller:"activity_notification/notifications_with_devise", action:"index", target_type:"users", devise_type:"users" }
    #     user_notification           GET    /users/:user_id/notifications/:id(.:format)
    #       { controller:"activity_notification/notifications_with_devise", action:"show", target_type:"users", devise_type:"users" }
    #     user_notification           DELETE /users/:user_id/notifications/:id(.:format)
    #       { controller:"activity_notification/notifications_with_devise", action:"destroy", target_type:"users", devise_type:"users" }
    #     open_all_user_notifications POST   /users/:user_id/notifications/open_all(.:format)
    #       { controller:"activity_notification/notifications_with_devise", action:"open_all", target_type:"users", devise_type:"users" }
    #     move_user_notification      POST   /users/:user_id/notifications/:id/move(.:format)
    #       { controller:"activity_notification/notifications_with_devise", action:"move", target_type:"users", devise_type:"users" }
    #     open_user_notification      POST   /users/:user_id/notifications/:id/open(.:format)
    #       { controller:"activity_notification/notifications_with_devise", action:"open", target_type:"users", devise_type:"users" }
    #
    # @example Define notify_to in config/routes.rb
    #   notify_to :users
    # @example Define notify_to with options
    #   notify_to :users, only: [:open, :open_all, :move]
    # @example Integrated with Devise authentication
    #   notify_to :users, with_devise: :users
    #
    # @overload notify_to(*resources, *options)
    #   @param          [Symbol] resources Resources to notify
    #   @option options [Symbol] :with_devise Devise resources name for devise integration. Devise integration will be enabled by this option.
    #   @option options [String] :controller  controller option as resources routing
    #   @option options [Symbol] :as          as option as resources routing
    #   @option options [Array]  :only        only option as resources routing
    #   @option options [Array]  :except      except option as resources routing
    # @return [ActionDispatch::Routing::Mapper] Routing mapper instance
    def notify_to(*resources)
      options = resources.extract_options!
      
      #TODO check resources if it includes target module

      if (with_devise = options.delete(:with_devise)).present?
        options[:controller] ||= "activity_notification/notifications_with_devise"
        options[:as]         ||= "notifications"
        #TODO check devise configuration in model
        devise_defaults        = { devise_type: with_devise.to_s }
      else
        options[:controller] ||= "activity_notification/notifications"
      end
      
      if (with_subscription = options.delete(:with_subscription)).present?
        subscription_option = with_subscription.is_a?(Hash) ? with_subscription : {}
        subscription_option = subscription_option.merge(with_devise: with_devise)
      end
      options[:except]       ||= []
      options[:except].concat( [:new, :create, :edit, :update] )
      notification_resources   = options[:model] || :notifications

      #TODO other options
      # :as, :path_prefix, :path_names ...

      resources.each do |resource|
        self.resources resource, only: :none do
          options[:defaults] = (devise_defaults || {}).merge({ target_type: resource.to_s })
          self.resources notification_resources, options do
            collection do
              post :open_all unless ignore_path?(:open_all, options)
            end
            member do
              get  :move     unless ignore_path?(:move, options)
              post :open     unless ignore_path?(:open, options)
            end
          end
        end

        if resource.to_s.to_model_class.subscription_enabled? and with_subscription.present?
          subscribed_by resource, subscription_option
        end
      end

      self
    end

    def subscribed_by(*resources)
      options = resources.extract_options!
      
      #TODO check resources if it includes target module

      if (with_devise = options.delete(:with_devise)).present?
        options[:controller] ||= "activity_notification/subscriptions_with_devise"
        options[:as]         ||= "subscriptions"
        #TODO check devise configuration in model
        devise_defaults        = { devise_type: with_devise.to_s }
      else
        options[:controller] ||= "activity_notification/subscriptions"
      end
      options[:except]       ||= []
      options[:except].concat( [:new, :edit, :update] )
      subscription_resources   = options[:model] || :subscriptions

      #TODO other options
      # :as, :path_prefix, :path_names ...

      resources.each do |resource|
        self.resources resource, only: :none do
          options[:defaults] = (devise_defaults || {}).merge({ target_type: resource.to_s })
          self.resources subscription_resources, options do
            member do
              post :subscribe            unless ignore_path?(:subscribe, options)
              post :unsubscribe          unless ignore_path?(:unsubscribe, options)
              post :subscribe_to_email   unless ignore_path?(:subscribe_to_email, options)
              post :unsubscribe_to_email unless ignore_path?(:unsubscribe_to_email, options)
            end
          end
        end
      end

      self
    end


    private

      def ignore_path?(action, options)
        return true if options[:except].present? and     options[:except].include?(action)
        return true if options[:only].present?   and not options[:only].include?(action)
        false
      end

  end
end
