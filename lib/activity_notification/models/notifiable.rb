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
      plural_target_type       = target_type.to_s.underscore.pluralize
      plural_target_type_sym   = plural_target_type.to_sym
      target_typed_method_name = "notification_#{plural_target_type}"
      if respond_to?(target_typed_method_name)
        send(target_typed_method_name, key)
      else
        if _notification_targets[plural_target_type_sym]
          resolve_value(_notification_targets[plural_target_type_sym], key)
        else
          raise NotImplementedError, "You have to implement #{self.class}##{target_typed_method_name} or set :targets in acts_as_notifiable"
        end
      end
    end

    def notification_group(target_type, key)
      plural_target_type       = target_type.to_s.underscore.pluralize
      plural_target_type_sym   = plural_target_type.to_sym
      target_typed_method_name = "notification_group_for_#{plural_target_type}"
      if respond_to?(target_typed_method_name)
        send(target_typed_method_name, key)
      else
        resolve_value(_notification_group[plural_target_type_sym])
      end
    end

    def notification_parameters(target_type, key)
      plural_target_type       = target_type.to_s.underscore.pluralize
      plural_target_type_sym   = plural_target_type.to_sym
      target_typed_method_name = "notification_parameters_for_#{plural_target_type}"
      if respond_to?(target_typed_method_name)
        send(target_typed_method_name, key)
      else
        resolve_value(_notification_parameters[plural_target_type_sym], key) || {}
      end
    end

    def notifier(target_type, key)
      plural_target_type       = target_type.to_s.underscore.pluralize
      plural_target_type_sym   = plural_target_type.to_sym
      target_typed_method_name = "notifier_for_#{plural_target_type}"
      if respond_to?(target_typed_method_name)
        send(target_typed_method_name, key)
      else
        resolve_value(_notifier[plural_target_type_sym])
      end
    end

    def notification_email_allowed?(target, key)
      plural_target_type_sym   = target.to_resources_name.to_sym
      if _notification_email_allowed[plural_target_type_sym]
        resolve_value(_notification_email_allowed[plural_target_type_sym], target, key)
      else
        ActivityNotification.config.email_enabled
      end
    end

    def notifiable_path(target_type, key = nil)
      plural_target_type       = target_type.to_s.underscore.pluralize
      plural_target_type_sym   = plural_target_type.to_sym
      target_typed_method_name = "notifiable_path_for_#{plural_target_type}"
      if respond_to?(target_typed_method_name)
        send(target_typed_method_name, key)
      elsif _notifiable_path[plural_target_type_sym]
        resolve_value(_notifiable_path[plural_target_type_sym])
      else
        begin
          polymorphic_path(self)
        rescue NoMethodError => e
          raise NotImplementedError, "You have to implement #{self.class}##{__method__}, set :notifiable_path in acts_as_notifiable or set polymorphic_path routing for #{self.class}"
        rescue ActionController::UrlGenerationError => e
          raise NotImplementedError, "You have to implement #{self.class}##{__method__}, set :notifiable_path in acts_as_notifiable or set polymorphic_path routing for #{self.class}"
        end
      end
    end

    # TODO docs
    # overriding_notification_render_key(target, key)

    # TODO docs
    # overriding_notification_email_key(target, key)

    # Wrapper methods of SimpleNotify class methods
  
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
  end
end