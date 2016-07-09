require "active_support/core_ext/object/try"
require "active_support/core_ext/hash/slice"

module ActionDispatch::Routing
  class Mapper
    # Includes notify_to method for routes.
    # This method is responsible to generate all needed routes for activity_notification
    #
    # ==== Examples
    #
    #   notify_to :users
    #   notify_to :users, with_devise: :users
    #   notify_to :users, with_devise: :users, only: [:open, :open_all, :move]
    #
    # When you have an User model configured as a target (e.g. defined acts_as_target),
    # you can creat this inside your routes:
    #
    #   notify_to :users
    #
    # This method creates the needed routes:
    #
    #  # Notification routes
    #          user_notifications GET    /users/:user_id/notifications(.:format)
    #                                    {controller:"activity_notification/notifications", action:"index", target_type:"users"}
    #           user_notification GET    /users/:user_id/notifications/:id(.:format)
    #                                    {controller:"activity_notification/notifications", action:"show", target_type:"users"}
    #           user_notification DELETE /users/:user_id/notifications/:id(.:format)
    #                                    {controller:"activity_notification/notifications", action:"destroy", target_type:"users"}
    # open_all_user_notifications POST   /users/:user_id/notifications/open_all(.:format)
    #                                      {controller:"activity_notification/notifications", action:"open_all", target_type:"users"}
    #      move_user_notification POST   /users/:user_id/notifications/:id/move(.:format)
    #                                      {controller:"activity_notification/notifications", action:"move", target_type:"users"}
    #      open_user_notification POST   /users/:user_id/notifications/:id/open(.:format)
    #                                      {controller:"activity_notification/notifications", action:"open", target_type:"users"}
    #
    # When you use devise for authentication and you want make notification target assciated with devise,
    # you can creat this inside your routes:
    #
    #   notify_to :users, with_devise: true
    #
    # This with_devise option creates the needed routes assciated with devise authentication:
    #
    #  # Notification with devise routes
    #          user_notifications GET    /users/:user_id/notifications(.:format)
    #                                    {controller:"activity_notification/notifications_with_devise", action:"index", devise_type:"users", target_type:"users"}
    #           user_notification GET    /users/:user_id/notifications/:id(.:format)
    #                                    {controller:"activity_notification/notifications_with_devise", action:"show", devise_type:"users", target_type:"users"}
    #           user_notification DELETE /users/:user_id/notifications/:id(.:format)
    #                                    {controller:"activity_notification/notifications_with_devise", action:"destroy", devise_type:"users", target_type:"users"}
    # open_all_user_notifications POST   /users/:user_id/notifications/open_all(.:format)
    #                                      {controller:"activity_notification/notifications_with_devise", action:"open_all", devise_type:"users", target_type:"users"}
    #      move_user_notification POST   /users/:user_id/notifications/:id/move(.:format)
    #                                      {controller:"activity_notification/notifications_with_devise", action:"move", devise_type:"users", target_type:"users"}
    #      open_user_notification POST   /users/:user_id/notifications/:id/open(.:format)
    #                                      {controller:"activity_notification/notifications_with_devise", action:"open", devise_type:"users", target_type:"users"}
    #
    # ==== Options
    #TODO add document for options
    #
    def notify_to(*resources)
      options = resources.extract_options!
      
      #TODO check resources if it includes target module

      if (with_devise = options.delete(:with_devise)).present?
        options[:controller] ||= "activity_notification/notifications_with_devise"
        options[:as]         ||= "notifications"
        #TODO check device configuration in model
        devise_defaults        = { devise_type: with_devise.to_s }
      else
        options[:controller] ||= "activity_notification/notifications"
      end
      options[:except]       ||= []
      options[:except].concat( [:new, :create, :edit, :update] )

      #TODO other options
      # :as, :path_prefix, :path_names ...

      resources.each do |resource|
        self.resources resource, only: :none do
          options[:defaults] = (devise_defaults || {}).merge({ target_type: resource.to_s })
          self.resources :notifications, options do
            collection do
              post :open_all unless ignore_path?(:open_all, options)
            end
            member do
              get  :move     unless ignore_path?(:move, options)
              post :open     unless ignore_path?(:open, options)
            end
          end
        end
      end

    end

    private

      def ignore_path?(action, options)
        return true if options[:except].present? and     options[:except].include?(action)
        return true if options[:only].present?   and not options[:only].include?(action)
        false
      end

  end
end
