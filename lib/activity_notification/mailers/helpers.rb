module ActivityNotification
  # Mailer module of ActivityNotification
  module Mailers
    # Provides helper methods for mailer.
    # Use to resolve parameters from email configuration and send notification email.
    module Helpers
      extend ActiveSupport::Concern

      protected

        # Send notification email with configured options.
        #
        # @param [Notification] notification Notification instance
        # @param [Hash] options Options for email notification
        def notification_mail(notification, options = {})
          initialize_from_notification(notification)
          headers = headers_for(notification.key, options)
          begin
            mail headers
          rescue ActionView::MissingTemplate
            mail headers.merge(template_name: 'default')
          end
        end
  
        # Initialize instance variables from notification.
        #
        # @param [Notification] notification Notification instance
        def initialize_from_notification(notification)
          @notification, @target, @notifiable = notification, notification.target, notification.notifiable
        end
  
        # Prepare email header from notification key and options.
        #
        # @param [String] key Key of the notification
        # @param [Hash] options Options for email notification
        def headers_for(key, options)
          if @notifiable.respond_to?(:overriding_notification_email_key) and 
             @notifiable.overriding_notification_email_key(@target, key).present?
            key = @notifiable.overriding_notification_email_key(@target, key)
          end
          headers = {
            subject: subject_for(key),
            to: mailer_to(@target),
            from: mailer_from(@notification),
            reply_to: mailer_reply_to(@notification),
            template_path: template_paths,
            template_name: template_name(key)
          }.merge(options)
  
          @email = headers[:to]
          headers
        end
  
        # Returns target email address as 'to'.
        #
        # @param [Object] target Target instance to notify
        # @return [String] Target email address as 'to'
        def mailer_to(target)
          target.mailer_to
        end
  
        # Returns sender email address as 'reply_to'.
        #
        # @param [Notification] notification Notification instance
        # @return [String] Sender email address as 'reply_to'
        def mailer_reply_to(notification)
          mailer_sender(notification, :reply_to)
        end
  
        # Returns sender email address as 'from'.
        #
        # @param [Notification] notification Notification instance
        # @return [String] Sender email address as 'from'
        def mailer_from(notification)
          mailer_sender(notification, :from)
        end
  
        # Returns sender email address configured in initializer or mailer class.
        #
        # @param [Notification] notification Notification instance
        # @return [String] Sender email address configured in initializer or mailer class
        def mailer_sender(notification, sender = :from)
          default_sender = default_params[sender]
          if default_sender.present?
            default_sender.respond_to?(:to_proc) ? instance_eval(&default_sender) : default_sender
          elsif ActivityNotification.config.mailer_sender.is_a?(Proc)
            ActivityNotification.config.mailer_sender.call(notification)
          else
            ActivityNotification.config.mailer_sender
          end
        end
  
        # Returns template paths to find email view
        #
        # @return [Array<String>] Template paths to find email view
        def template_paths
          paths = ['activity_notification/mailer/default']
          paths.unshift("activity_notification/mailer/#{@target.to_resources_name}") if @target.present?
          paths
        end
  
        # Returns template name from notification key
        #
        # @param [String] key Key of the notification
        # @return [String] Template name
        def template_name(key)
          key.gsub('.', '/')
        end
  
  
        # Set up a subject doing an I18n lookup.
        # At first, it attempts to set a subject based on the current mapping:
        #   en:
        #     notification:
        #       {target}:
        #         {key}:
        #           mail_subject: '...'
        #
        # If one does not exist, it fallbacks to default:
        #   Notification for #{notification.printable_type}
        #
        # @param [String] key Key of the notification
        # @return [String] Subject of notification email
        def subject_for(key)
          k = key.split('.')
          k.unshift('notification') if k.first != 'notification'
          k.insert(1, @target.to_resource_name)
          k = k.join('.')
          I18n.t(:mail_subject, scope: k,
            default: ["Notification of #{@notifiable.printable_type}"])
        end

    end
  end
end
