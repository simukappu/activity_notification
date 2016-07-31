# Provides a shortcut from views to the rendering method.
module ActivityNotification
  # Module extending ActionView::Base and adding `render_notification` helper.
  module ViewHelpers
    # View helper for rendering an notification, calls {ActivityNotification::Notification#render} internally.
    def render_notification notifications, options = {}
      if notifications.is_a? ActivityNotification::Notification
        notifications.render self, options
      elsif notifications.respond_to?(:map)
        return nil if notifications.empty?
        notifications.map {|notification| notification.render self, options.dup }.join.html_safe
      end
    end
    alias_method :render_notifications, :render_notification

    # View helper for rendering embedded partial template of target's notifications
    def render_notification_of target, options = {}
      return unless target.is_a? ActivityNotification::Target

      partial_path = options.delete(:partial) || "index"
      partial_root = options[:partial_root] ||
                         "activity_notification/notifications/#{target.to_resources_name}"
      partial      = select_path(partial_path, partial_root)
      layout       = options[:layout].present? ?
                       select_path(options.delete(:layout), (options[:layout_root] || "layouts")) :
                       nil
      locals       = (options[:locals] || {}).merge(target: target)

      # Prepare content for notifications index
      notification_options = options.merge\
                               target:  target.to_resources_name, 
                               partial: options[:notification_partial], 
                               layout:  options[:notification_layout]
      case options[:index_content]
      when :simple
        notification_index = target.notification_index
      when :none
      else
        notification_index = target.notification_index_with_attributes
      end

      if notification_index.present?
        content_for :notification_index do
          begin
            render_notifications notification_index, notification_options
          rescue ActionView::MissingTemplate => e
            notification_options.delete(:target)
            render_notifications notification_index, notification_options
          end
        end
      end

      # Render partial index
      begin
        render options.merge(partial: partial, layout: layout, locals: locals)
      rescue ActionView::MissingTemplate => e
        partial_root = "activity_notification/notifications/default"
        partial      = select_path(partial_path, partial_root)
        render options.merge(partial: partial, layout: layout, locals: locals)
      end
    end
    alias_method :render_notifications_of, :render_notification_of

    # Url helper methods
    #TODO Is there any other better solution?
    #TODO Must handle devise namespace
    def notification_path_for(notification, params = {})
      send("#{notification.target.to_resource_name}_notification_path", notification.target, notification, params)
    end

    def move_notification_path_for(notification, params = {})
      send("move_#{notification.target.to_resource_name}_notification_path", notification.target, notification, params)
    end

    def open_notification_path_for(notification, params = {})
      send("open_#{notification.target.to_resource_name}_notification_path", notification.target, notification, params)
    end

    def open_all_notifications_path_for(target, params = {})
      send("open_all_#{target.to_resource_name}_notifications_path", target, params)
    end

    def notification_url_for(notification, params = {})
      send("#{notification.target.to_resource_name}_notification_url", notification.target, notification, params)
    end

    def move_notification_url_for(notification, params = {})
      send("move_#{notification.target.to_resource_name}_notification_url", notification.target, notification, params)
    end

    def open_notification_url_for(notification, params = {})
      send("open_#{notification.target.to_resource_name}_notification_url", notification.target, notification, params)
    end

    def open_all_notifications_url_for(target, params = {})
      send("open_all_#{target.to_resource_name}_notifications_url", target, params)
    end

    private

      def select_path(path, root)
        [root, path].map(&:to_s).join('/')
      end

  end

  ActionView::Base.class_eval { include ViewHelpers }
end