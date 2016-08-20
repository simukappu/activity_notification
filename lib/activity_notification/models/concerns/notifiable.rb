module ActivityNotification
  module Notifiable
    extend ActiveSupport::Concern

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
  
    def default_url_options
      Rails.application.routes.default_url_options
    end
    
    class_methods do
      def available_as_notifiable?
        true
      end

      def set_notifiable_class_defaults
        self._notification_targets        = {}
        self._notification_group          = {}
        self._notifier                    = {}
        self._notification_parameters     = {}
        self._notification_email_allowed  = {}
        self._notifiable_path             = {}
      end
    end

    # Methods to be overriden

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

    def notification_group(target_type, key)
      resolved_parameter = resolve_parameter(
        "notification_group_for_#{target_type.to_s.to_resources_name}",
        _notification_group[target_type.to_s.to_resources_name.to_sym],
        nil,
        key)
    end

    def notification_parameters(target_type, key)
      resolved_parameter = resolve_parameter(
        "notification_parameters_for_#{target_type.to_s.to_resources_name}",
        _notification_parameters[target_type.to_s.to_resources_name.to_sym],
        {},
        key)
    end

    def notifier(target_type, key)
      resolved_parameter = resolve_parameter(
        "notifier_for_#{target_type.to_s.to_resources_name}",
        _notifier[target_type.to_s.to_resources_name.to_sym],
        nil,
        key)
    end

    def notification_email_allowed?(target, key)
      resolved_parameter = resolve_parameter(
        "notification_email_allowed_for_#{target.class.to_s.to_resources_name}?",
        _notification_email_allowed[target.class.to_s.to_resources_name.to_sym],
        ActivityNotification.config.email_enabled,
        target, key)
    end

    def notifiable_path(target_type, key = nil)
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

    # Methods to override key definition
    # TODO docs
    # overriding_notification_render_key(target, key)
    # overriding_notification_email_key(target, key)

    # Wrapper methods of Notification class methods
  
    def notify(target_type, options = {})
      Notification.notify(target_type, self, options)
    end
  
    def notify_to(target, options = {})
      Notification.notify_to(target, self, options)
    end
  
    def notify_all(targets, options = {})
      Notification.notify_all(targets, self, options)
    end

    def default_notification_key
      "#{to_resource_name}.default"
    end

    private

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