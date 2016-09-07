module ActivityNotification
  # Notifiable implementation included in notifiable model to be notified, like comments or any other user activities.
  module Notifiable
    extend ActiveSupport::Concern
    # include PolymorphicHelpers to resolve string extentions
    include ActivityNotification::PolymorphicHelpers

    included do
      include Common
      include ActionDispatch::Routing::PolymorphicRoutes
      include Rails.application.routes.url_helpers
      class_attribute  :_notification_targets,
                       :_notification_group,
                       :_notifier,
                       :_notification_parameters,
                       :_notification_email_allowed,
                       :_notifiable_path
      set_notifiable_class_defaults
    end
  
    # Returns default_url_options for polymorphic_path.
    # @return [Hash] Rails.application.routes.default_url_options
    def default_url_options
      Rails.application.routes.default_url_options
    end
    
    class_methods do
      # Checks if the model includes notifiable and notifiable methods are available.
      # @return [Boolean] Always true
      def available_as_notifiable?
        true
      end

      # Sets default values to notifiable class fields.
      # @return [Nil] nil
      def set_notifiable_class_defaults
        self._notification_targets        = {}
        self._notification_group          = {}
        self._notifier                    = {}
        self._notification_parameters     = {}
        self._notification_email_allowed  = {}
        self._notifiable_path             = {}
        nil
      end
    end

    # Returns notification targets from configured field or overriden method.
    # This method is able to be overriden.
    #
    # @param [String] target_type Target type to notify
    # @param [String] key Key of the notification
    # @return [Array<Notificaion> | ActiveRecord_AssociationRelation<Notificaion>] Array or database query of the notification targets
    def notification_targets(target_type, key)
      target_typed_method_name = "notification_#{target_type.to_s.to_resources_name}"
      resolved_parameter = resolve_parameter(
        target_typed_method_name,
        _notification_targets[target_type.to_s.to_resources_name.to_sym],
        nil,
        key)
      unless resolved_parameter
        raise NotImplementedError, "You have to implement #{self.class}##{target_typed_method_name} "\
                                   "or set :targets in acts_as_notifiable"
      end
      resolved_parameter
    end

    # Returns group owner of the notification from configured field or overriden method.
    # This method is able to be overriden.
    #
    # @param [String] target_type Target type to notify
    # @param [String] key Key of the notification
    # @return [Object] Group owner of the notification
    def notification_group(target_type, key)
      resolve_parameter(
        "notification_group_for_#{target_type.to_s.to_resources_name}",
        _notification_group[target_type.to_s.to_resources_name.to_sym],
        nil,
        key)
    end

    # Returns additional notification parameters from configured field or overriden method.
    # This method is able to be overriden.
    #
    # @param [String] target_type Target type to notify
    # @param [String] key Key of the notification
    # @return [Hash] Additional notification parameters
    def notification_parameters(target_type, key)
      resolve_parameter(
        "notification_parameters_for_#{target_type.to_s.to_resources_name}",
        _notification_parameters[target_type.to_s.to_resources_name.to_sym],
        {},
        key)
    end

    # Returns notifier of the notification from configured field or overriden method.
    # This method is able to be overriden.
    #
    # @param [String] target_type Target type to notify
    # @param [String] key Key of the notification
    # @return [Object] Notifier of the notification
    def notifier(target_type, key)
      resolve_parameter(
        "notifier_for_#{target_type.to_s.to_resources_name}",
        _notifier[target_type.to_s.to_resources_name.to_sym],
        nil,
        key)
    end

    # Returns if sending notification email is allowed for the notifiable from configured field or overriden method.
    # This method is able to be overriden.
    #
    # @param [Object] target Target instance to notify
    # @param [String] key Key of the notification
    # @return [Boolean] If sending notification email is allowed for the notifiable
    def notification_email_allowed?(target, key)
      resolve_parameter(
        "notification_email_allowed_for_#{target.class.to_s.to_resources_name}?",
        _notification_email_allowed[target.class.to_s.to_resources_name.to_sym],
        ActivityNotification.config.email_enabled,
        target, key)
    end

    # Returns notifiable_path to move after opening notification from configured field or overriden method.
    # This method is able to be overriden.
    #
    # @param [String] target_type Target type to notify
    # @param [String] key Key of the notification
    # @return [String] Notifiable path URL to move after opening notification
    def notifiable_path(target_type, key)
      resolved_parameter = resolve_parameter(
        "notifiable_path_for_#{target_type.to_s.to_resources_name}",
        _notifiable_path[target_type.to_s.to_resources_name.to_sym],
        nil,
        key)
      unless resolved_parameter
        begin
          resolved_parameter = polymorphic_path(self)
        rescue NoMethodError, ActionController::UrlGenerationError
          raise NotImplementedError, "You have to implement #{self.class}##{__method__}, "\
                                     "set :notifiable_path in acts_as_notifiable or "\
                                     "set polymorphic_path routing for #{self.class}"
        end
      end
      resolved_parameter
    end

    # overriding_notification_email_key is the method to override key definition for Mailer
    # When respond_to?(overriding_notification_email_key) returns true,
    # Mailer uses overriding_notification_email_key instead of original key.
    #
    # overriding_notification_email_key(target, key)


    # Generates notifications to configured targets with notifiable model.
    # This method calls NotificationApi#notify internally with self notifiable instance.
    # @see NotificationApi#notify
    #
    # @param [Symbol, String, Class] target_type Type of target
    # @param [Hash] options Options for notifications
    # @option options [String]  :key        (notifiable.default_notification_key) Notification key
    # @option options [Object]  :group      (nil)                                 Group unit of the notifications
    # @option options [Object]  :notifier   (nil)                                 Notifier of the notifications
    # @option options [Hash]    :parameters ({})                                  Additional parameters of the notifications
    # @option options [Boolean] :send_email (true)                                If it sends notification email
    # @option options [Boolean] :send_later (true)                                If it sends notification email asynchronously
    # @return [Array<Notificaion>] Array of generated notifications
    def notify(target_type, options = {})
      Notification.notify(target_type, self, options)
    end

    # Generates notifications to one target.
    # This method calls NotificationApi#notify_all internally with self notifiable instance.
    # @see NotificationApi#notify_all
    #
    # @param [Array<Object>] targets Targets to send notifications
    # @param [Hash] options Options for notifications
    # @option options [String]  :key        (notifiable.default_notification_key) Notification key
    # @option options [Object]  :group      (nil)                                 Group unit of the notifications
    # @option options [Object]  :notifier   (nil)                                 Notifier of the notifications
    # @option options [Hash]    :parameters ({})                                  Additional parameters of the notifications
    # @option options [Boolean] :send_email (true)                                Whether it sends notification email
    # @option options [Boolean] :send_later (true)                                Whether it sends notification email asynchronously
    # @return [Array<Notificaion>] Array of generated notifications
    def notify_all(targets, options = {})
      Notification.notify_all(targets, self, options)
    end

    # Generates notifications to one target.
    # This method calls NotificationApi#notify_to internally with self notifiable instance.
    # @see NotificationApi#notify_to
    #
    # @param [Object] target Target to send notifications
    # @param [Hash] options Options for notifications
    # @option options [String]  :key        (notifiable.default_notification_key) Notification key
    # @option options [Object]  :group      (nil)                                 Group unit of the notifications
    # @option options [Object]  :notifier   (nil)                                 Notifier of the notifications
    # @option options [Hash]    :parameters ({})                                  Additional parameters of the notifications
    # @option options [Boolean] :send_email (true)                                Whether it sends notification email
    # @option options [Boolean] :send_later (true)                                Whether it sends notification email asynchronously
    # @return [Notification] Generated notification instance
    def notify_to(target, options = {})
      Notification.notify_to(target, self, options)
    end

    # Returns default notification key.
    # This method is able to be overriden.
    # "#{to_resource_name}.default" is defined as default key.
    #
    # @return [String] Default notification key
    def default_notification_key
      "#{to_resource_name}.default"
    end

    private

      # Used to transform parameter value from configured field or defined method.
      # @api private
      #
      # @param [String] target_typed_method_name Method name overriden for the target type
      # @param [Object] parameter_field Parameter Configured field in this model
      # @param [Object] default_value Default parameter value
      # @param [Array] args Arguments to pass to the method overriden or defined as parameter field
      # @return [Object] Resolved parameter value
      def resolve_parameter(target_typed_method_name, parameter_field, default_value, *args)
        if respond_to?(target_typed_method_name)
          send(target_typed_method_name, *args)
        elsif parameter_field
          resolve_value(parameter_field, *args)
        else
          default_value
        end
      end
  end
end