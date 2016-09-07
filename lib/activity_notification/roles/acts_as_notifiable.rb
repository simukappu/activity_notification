module ActivityNotification
  # Manages to add all required configurations to notifiable models.
  module ActsAsNotifiable
    extend ActiveSupport::Concern

    class_methods do
      # Adds required configurations to notifiable models.
      #
      # == Parameters:
      # * :targets
      #   * Targets to send notifications.
      #     It it set as ActiveRecord records or array of models.
      #     This is a only necessary option.
      #     If you do not specify this option, you have to override notification_targets
      #     or notification_[plural target type] (e.g. notification_users) method.
      # @example Notify to all users
      #   class Comment < ActiveRecord::Base
      #     acts_as_notifiable :users, targets: User.all
      #   end
      # @example Notify to author and users commented to the article, except comment owner self
      #   class Comment < ActiveRecord::Base
      #     belongs_to :article
      #     belongs_to :user
      #     acts_as_notifiable :users,
      #       targets: ->(comment, key) {
      #         ([comment.article.user] + comment.article.commented_users.to_a - [comment.user]).uniq
      #       }
      #   end
      #
      # * :group
      #   * Group unit of notifications.
      #     Notifications will be bundled by this group (and target, notifiable_type, key).
      #     This parameter is a optional.
      # @example All *unopened* notifications to the same target will be grouped by `article`
      #   class Comment < ActiveRecord::Base
      #     belongs_to :article
      #     acts_as_notifiable :users, targets: User.all, group: :article
      #   end
      #
      # * :notifier
      #   * Notifier of the notification.
      #     This will be stored as notifier with notification record.
      #     This parameter is a optional.
      # @example Set comment owner self as notifier
      #   class Comment < ActiveRecord::Base
      #     belongs_to :article
      #     belongs_to :user
      #     acts_as_notifiable :users, targets: User.all, notifier: :user
      #   end
      #
      # * :parameters
      #   * Additional parameters of the notifications.
      #     This will be stored as parameters with notification record.
      #     You can use these additional parameters in your notification view or i18n text.
      #     This parameter is a optional.
      # @example Set constant values as additional parameter
      #   class Comment < ActiveRecord::Base
      #     acts_as_notifiable :users, targets: User.all, parameters: { default_param: '1' }
      #   end
      # @example Set comment body as additional parameter
      #   class Comment < ActiveRecord::Base
      #     acts_as_notifiable :users, targets: User.all, parameters: ->(comment, key) { body: comment.body }
      #   end
      #
      # * :email_allowed
      #   * Whether activity_notification sends notification email.
      #     Specified method or symbol is expected to return true (not nil) or false (nil).
      #     This parameter is a optional since default value is false.
      #     To use notification email, email_allowed option must return true (not nil) in both of notifiable and target model.
      #     This can be also configured default option in initializer.
      # @example Enable email notification for this notifiable model
      #   class Comment < ActiveRecord::Base
      #     acts_as_notifiable :users, targets: User.all, email_allowed: true
      #   end
      #
      # * :notifiable_path
      #   * Path to redirect from open or move action of notification controller.
      #     You can also use this notifiable_path as notifiable link in notification view.
      #     This parameter is a optional since polymorphic_path is used as default value.
      # @example Redirect to parent article page from comment notifications
      #   class Comment < ActiveRecord::Base
      #     belongs_to :article
      #     acts_as_notifiable :users, targets: User.all, notifiable_path: :article_notifiable_path
      #
      #     def article_notifiable_path
      #       article_path(article)
      #     end
      #   end
      #
      # @param [Symbol] target_type Type of notification target as symbol
      # @param [Hash] options Options for notifiable model configuration
      # @option options [Symbol, Proc, Array]   :targets         (nil)                    Targets to send notifications
      # @option options [Symbol, Proc, Object]  :group           (nil)                    Group unit of the notifications
      # @option options [Symbol, Proc, Object]  :notifier        (nil)                    Notifier of the notifications
      # @option options [Symbol, Proc, Hash]    :parameters      ({})                     Additional parameters of the notifications
      # @option options [Symbol, Proc, Boolean] :email_allowed   (false)                  Whether activity_notification sends notification email
      # @option options [Symbol, Proc, String]  :notifiable_path (polymorphic_path(self)) Path to redirect from open or move action of notification controller
      # @return [Hash] Configured parameters as notifiable model
      def acts_as_notifiable(target_type, options = {})
        include Notifiable
        (
          [:targets, :group, :parameters, :email_allowed].map { |key|
            assign_parameter(target_type, key, "_notification_#{key}", options)
          }.to_h.merge [:notifier, :notifiable_path].map { |key|
            assign_parameter(target_type, key, "_#{key}", options)
          }.to_h
        ).delete_if { |k, _| k.nil? }
      end

      # Returns array of available notifiable options in acts_as_notifiable.
      # @return [Array] Array of available notifiable options
      def available_notifiable_options
        [:targets, :group, :notifier, :parameters, :email_allowed, :notifiable_path].freeze
      end

      private

        def assign_parameter(target_type, key, field_name, options)
          options[key] ?
            [key, self.send(field_name.to_sym).store(target_type.to_sym, options.delete(key))] :
            [nil, nil]
        end
    end
  end
end
