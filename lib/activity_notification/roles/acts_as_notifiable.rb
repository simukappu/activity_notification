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
      #   # app/models/comment.rb
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
      #   # app/models/comment.rb
      #   class Comment < ActiveRecord::Base
      #     belongs_to :article
      #     acts_as_notifiable :users, targets: User.all, group: :article
      #   end
      #
      # * :group_expiry_delay
      #   * Expiry period of a notification group.
      #     Notifications will be bundled within the group expiry period.
      #     This parameter is a optional.
      # @example All *unopened* notifications to the same target within 1 day will be grouped by `article`
      #   # app/models/comment.rb
      #   class Comment < ActiveRecord::Base
      #     belongs_to :article
      #     acts_as_notifiable :users, targets: User.all, group: :article, :group_expiry_delay: 1.day
      #   end
      #
      # * :notifier
      #   * Notifier of the notification.
      #     This will be stored as notifier with notification record.
      #     This parameter is a optional.
      # @example Set comment owner self as notifier
      #   # app/models/comment.rb
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
      #   # app/models/comment.rb
      #   class Comment < ActiveRecord::Base
      #     acts_as_notifiable :users, targets: User.all, parameters: { default_param: '1' }
      #   end
      # @example Set comment body as additional parameter
      #   # app/models/comment.rb
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
      #   # app/models/comment.rb
      #   class Comment < ActiveRecord::Base
      #     acts_as_notifiable :users, targets: User.all, email_allowed: true
      #   end
      #
      # * :notifiable_path
      #   * Path to redirect from open or move action of notification controller.
      #     You can also use this notifiable_path as notifiable link in notification view.
      #     This parameter is a optional since polymorphic_path is used as default value.
      # @example Redirect to parent article page from comment notifications
      #   # app/models/comment.rb
      #   class Comment < ActiveRecord::Base
      #     belongs_to :article
      #     acts_as_notifiable :users, targets: User.all, notifiable_path: :article_notifiable_path
      #
      #     def article_notifiable_path
      #       article_path(article)
      #     end
      #   end
      #
      # * :printable_name or :printable_notifiable_name
      #   * Printable notifiable name.
      #     This parameter is a optional since `ActivityNotification::Common.printable_name` is used as default value.
      #     :printable_name is the same option as :printable_notifiable_name
      # @example Define printable name with comment body
      #   # app/models/comment.rb
      #   class Comment < ActiveRecord::Base
      #     acts_as_notifiable :users, targets: User.all, printable_name: ->(comment) { "comment \"#{comment.body}\"" }
      #   end
      #
      # * :dependent_notifications
      #   * Dependency for notifications to delete generated notifications with this notifiable.
      #     This option is used to configure generated_notifications_as_notifiable association.
      #     You can use :delete_all, :destroy, or :nullify for this option.
      #     This parameter is a optional since no dependent option is used as default.
      # @example Define :delete_all dependency to generated notifications
      #   # app/models/comment.rb
      #   class Comment < ActiveRecord::Base
      #     acts_as_notifiable :users, targets: User.all, dependent_notifications: :delete_all
      #   end
      #
      # @param [Symbol] target_type Type of notification target as symbol
      # @param [Hash] options Options for notifiable model configuration
      # @option options [Symbol, Proc, Array]   :targets                 (nil)                    Targets to send notifications
      # @option options [Symbol, Proc, Object]  :group                   (nil)                    Group unit of the notifications
      # @option options [Symbol, Proc, Object]  :group_expiry_delay      (nil)                    Expiry period of a notification group
      # @option options [Symbol, Proc, Object]  :notifier                (nil)                    Notifier of the notifications
      # @option options [Symbol, Proc, Hash]    :parameters              ({})                     Additional parameters of the notifications
      # @option options [Symbol, Proc, Boolean] :email_allowed           (ActivityNotification.config.email_enabled) Whether activity_notification sends notification email
      # @option options [Symbol, Proc, String]  :notifiable_path         (polymorphic_path(self)) Path to redirect from open or move action of notification controller
      # @option options [Symbol, Proc, String]  :printable_name          (ActivityNotification::Common.printable_name) Printable notifiable name
      # @option options [Symbol, Proc]          :dependent_notifications (nil)                    Dependency for notifications to delete generated notifications with this notifiable
      # @return [Hash] Configured parameters as notifiable model
      def acts_as_notifiable(target_type, options = {})
        include Notifiable

        if [:delete_all, :destroy, :nullify].include? options[:dependent_notifications] 
          has_many :generated_notifications_as_notifiable,
            class_name: "::ActivityNotification::Notification",
            as: :notifiable,
            dependent: options[:dependent_notifications]
        end

        options[:printable_notifiable_name] ||= options.delete(:printable_name)
        set_acts_as_parameters_for_target(target_type, [:targets, :group, :group_expiry_delay, :parameters, :email_allowed], options, "notification_")
          .merge set_acts_as_parameters_for_target(target_type, [:notifier, :notifiable_path, :printable_notifiable_name], options)
      end

      # Returns array of available notifiable options in acts_as_notifiable.
      # @return [Array<Symbol>] Array of available notifiable options
      def available_notifiable_options
        [ :targets,
          :group,
          :group_expiry_delay,
          :notifier,
          :parameters,
          :email_allowed,
          :notifiable_path,
          :printable_notifiable_name, :printable_name,
          :dependent_notifications
        ].freeze
      end
    end
  end
end
