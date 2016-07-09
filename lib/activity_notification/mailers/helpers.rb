module ActivityNotification
  module Mailers
    module Helpers
      extend ActiveSupport::Concern

      protected

      # Configure default email options
      def notification_mail(notification, options = {})
        initialize_from_notification(notification)
        headers = headers_for(notification.key, options)
        begin
          mail headers
        rescue ActionView::MissingTemplate => e
          mail headers.merge(template_name: 'default')
        end
      end

      def initialize_from_notification(notification)
        @notification, @target, @notifiable = notification, notification.target, notification.notifiable
      end

      def headers_for(key, options)
        if @notifiable.respond_to?(:overriding_notification_email_key) and 
           @notifiable.overriding_notification_email_key(@target, key).present?
          key = @notifiable.overriding_notification_email_key(@target, key)
        end
        headers = {
          subject: subject_for(key),
          to: mailer_to(@target),
          from: mailer_sender(@target.to_resource_name),
          reply_to: mailer_reply_to(@target.to_resource_name),
          template_path: template_paths,
          template_name: template_name(key)
        }.merge(options)

        @email = headers[:to]
        headers
      end

      def mailer_to(target)
        target.mailer_to
      end

      def mailer_reply_to(target_type)
        mailer_sender(target_type, :reply_to)
      end

      def mailer_from(target_type)
        mailer_sender(target_type, :from)
      end

      def mailer_sender(target_type, sender = :from)
        default_sender = default_params[sender]
        if default_sender.present?
          default_sender.respond_to?(:to_proc) ? instance_eval(&default_sender) : default_sender
        elsif ActivityNotification.config.mailer_sender.is_a?(Proc)
          ActivityNotification.config.mailer_sender.call(target_type)
        else
          ActivityNotification.config.mailer_sender
        end
      end

      def template_paths
        paths = ['activity_notification/mailer/default']
        paths.unshift("activity_notification/mailer/#{@target.to_resources_name}") if @target.present?
        paths
      end

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
