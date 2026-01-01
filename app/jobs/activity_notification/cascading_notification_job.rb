if defined?(ActiveJob)
  # Job to handle cascading notifications with time delays and read status checking.
  # This job enables sequential delivery of notifications through different channels
  # based on whether previous notifications were read.
  #
  # @example Basic usage
  #   cascade_config = [
  #     { delay: 10.minutes, target: :slack },
  #     { delay: 10.minutes, target: :email }
  #   ]
  #   CascadingNotificationJob.perform_later(notification.id, cascade_config, 0)
  class ActivityNotification::CascadingNotificationJob < ActivityNotification.config.parent_job.constantize
    queue_as ActivityNotification.config.active_job_queue
  
    # Performs a single step in the cascading notification chain.
    # Checks if the notification is still unread, and if so, triggers the next optional target
    # and schedules the next step in the cascade.
    #
    # @param [Integer] notification_id ID of the notification to check
    # @param [Array<Hash>] cascade_config Array of cascade step configurations
    # @option cascade_config [ActiveSupport::Duration] :delay Time to wait before checking and sending
    # @option cascade_config [Symbol, String] :target Name of the optional target to trigger (e.g., :slack, :email)
    # @option cascade_config [Hash] :options Optional parameters to pass to the optional target
    # @param [Integer] step_index Current step index in the cascade chain (0-based)
    # @return [Hash, nil] Result of triggering the optional target, or nil if notification was read or not found
    def perform(notification_id, cascade_config, step_index = 0)
      # Find the notification using ORM-appropriate method
      # :nocov:
      notification = case ActivityNotification.config.orm
                     when :dynamoid
                       ActivityNotification::Notification.find(notification_id, raise_error: false)
                     when :mongoid
                       begin
                         ActivityNotification::Notification.find(notification_id)
                       rescue Mongoid::Errors::DocumentNotFound
                         nil
                       end
                     else
                       ActivityNotification::Notification.find_by(id: notification_id)
                     end
      # :nocov:
      
      # Return early if notification not found or has been opened (read)
      return nil if notification.nil? || notification.opened?
      
      # Get current step configuration
      current_step = cascade_config[step_index]
      return nil if current_step.nil?
      
      # Extract step parameters
      target_name = current_step[:target] || current_step['target']
      target_options = current_step[:options] || current_step['options'] || {}
      
      # Trigger the optional target for this step
      result = trigger_optional_target(notification, target_name, target_options)
      
      # Schedule next step if available and notification is still unread
      next_step_index = step_index + 1
      if next_step_index < cascade_config.length
        next_step = cascade_config[next_step_index]
        delay = next_step[:delay] || next_step['delay']
        
        if delay.present?
          # Schedule the next step with the specified delay
          self.class.set(wait: delay).perform_later(
            notification_id,
            cascade_config,
            next_step_index
          )
        end
      end
      
      result
    end
    
    private
    
    # Triggers a specific optional target for the notification
    # @param [Notification] notification The notification instance
    # @param [Symbol, String] target_name Name of the optional target
    # @param [Hash] options Options to pass to the optional target
    # @return [Hash] Result of triggering the target
    def trigger_optional_target(notification, target_name, options = {})
      target_name_sym = target_name.to_sym
      
      # Get all configured optional targets for this notification
      optional_targets = notification.notifiable.optional_targets(
        notification.target.to_resources_name,
        notification.key
      )
      
      # Find the matching optional target
      optional_target = optional_targets.find do |ot|
        ot.to_optional_target_name == target_name_sym
      end
      
      if optional_target.nil?
        Rails.logger.warn("Optional target '#{target_name}' not found for notification #{notification.id}")
        return { target_name_sym => :not_configured }
      end
      
      # Check subscription status
      unless notification.optional_target_subscribed?(target_name_sym)
        Rails.logger.info("Target not subscribed to optional target '#{target_name}' for notification #{notification.id}")
        return { target_name_sym => :not_subscribed }
      end
      
      # Trigger the optional target
      begin
        optional_target.notify(notification, options)
        Rails.logger.info("Successfully triggered optional target '#{target_name}' for notification #{notification.id}")
        { target_name_sym => :success }
      rescue => e
        Rails.logger.error("Failed to trigger optional target '#{target_name}' for notification #{notification.id}: #{e.message}")
        if ActivityNotification.config.rescue_optional_target_errors
          { target_name_sym => e }
        else
          raise e
        end
      end
    end
  end
end
