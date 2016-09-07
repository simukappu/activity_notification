module ActivityNotification
  # Manages to add all required configurations to target models of notification.
  module ActsAsTarget
    extend ActiveSupport::Concern

    class_methods do
      # Adds required configurations to notifiable models.
      #
      # == Parameters:
      # * :email
      #   * Email address to send notification email.
      #     This is a necessary option when you enables email notification.
      # @example Simply use :email field
      #   class User < ActiveRecord::Base
      #     validates :email, presence: true
      #     acts_as_target email: :email
      #   end
      #
      # * :email_allowed
      #   * Whether activity_notification sends notification email to this target.
      #     Specified method or symbol is expected to return true (not nil) or false (nil).
      #     This parameter is a optional since default value is false.
      #     To use notification email, email_allowed option must return true (not nil) in both of notifiable and target model.
      #     This can be also configured default option in initializer.
      # @example Always enable email notification for this target
      #   class User < ActiveRecord::Base
      #     acts_as_target email: :email, email_allowed: true
      #   end
      # @example Use confirmed_at of devise field to decide whether activity_notification sends notification email to this user
      #   class User < ActiveRecord::Base
      #     acts_as_target email: :email, email_allowed: :confirmed_at
      #   end
      #
      # * :devise_resource
      #   * Integrated resource with devise authentication.
      #     This parameter is a optional since `self` is used as default value.
      #     You also have to configure routing for devise inroutes.rb
      # @example No :devise_resource is needed when notification target is the same as authenticated resource
      #   # config/routes.rb
      #   devise_for :users
      #   notify_to :users
      #
      #   # app/models/user.rb
      #   class User < ActiveRecord::Base
      #     devise :database_authenticatable, :registerable, :confirmable
      #     acts_as_target email: :email, email_allowed: :confirmed_at
      #   end
      #
      # @example Send Admin model and use associated User model with devise authentication
      #   # config/routes.rb
      #   devise_for :users
      #   notify_to :admins, with_devise: :users
      #
      #   # app/models/user.rb
      #   class User < ActiveRecord::Base
      #     devise :database_authenticatable, :registerable, :confirmable
      #   end
      #
      #   # app/models/admin.rb
      #   class Admin < ActiveRecord::Base
      #     belongs_to :user
      #     validates :user, presence: true
      #     acts_as_notification_target email: :email,
      #       email_allowed: ->(admin, key) { admin.user.confirmed_at.present? },
      #       devise_resource: :user
      #   end
      #
      # @param [Symbol] target_type Type of notification target as symbol
      # @param [Hash] options Options for notifiable model configuration
      # @option options [Symbol, Proc, Array]   :email           (nil) Email address to send notification email
      # @option options [Symbol, Proc, Object]  :email_allowed   (ActivityNotification.config.email_enabled) Whether activity_notification sends notification email to this target
      # @option options [Symbol, Proc, Object]  :devise_resource (nil) Integrated resource with devise authentication
      # @return [Hash] Configured parameters as target model
      def acts_as_target(options = {})
        include Target
        available_target_options.map { |key|
          options[key] ?
            [key, self.send("_notification_#{key}=".to_sym, options.delete(key))] :
            [nil, nil]
        }.to_h.delete_if { |k, v| k.nil? }
      end
      alias_method :acts_as_notification_target, :acts_as_target

      # Returns array of available target options in acts_as_target.
      # @return [Array<Symbol>] Array of available target options
      def available_target_options
        [:email, :email_allowed, :devise_resource].freeze
      end
    end
  end
end
