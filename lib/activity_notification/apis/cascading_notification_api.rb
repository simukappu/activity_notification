module ActivityNotification
  # Defines API for cascading notifications included in Notification model.
  # Cascading notifications enable sequential delivery through different channels
  # based on read status, with configurable time delays between each step.
  module CascadingNotificationApi
    extend ActiveSupport::Concern
    
    # Starts a cascading notification chain with the specified configuration.
    # The chain will automatically check the read status before each step and
    # only proceed if the notification remains unread.
    #
    # @example Simple cascade with Slack then email
    #   notification.cascade_notify([
    #     { delay: 10.minutes, target: :slack },
    #     { delay: 10.minutes, target: :email }
    #   ])
    #
    # @example Cascade with custom options for each target
    #   notification.cascade_notify([
    #     { delay: 5.minutes, target: :slack, options: { channel: '#alerts' } },
    #     { delay: 10.minutes, target: :amazon_sns, options: { subject: 'Urgent' } },
    #     { delay: 15.minutes, target: :email }
    #   ])
    #
    # @param [Array<Hash>] cascade_config Array of cascade step configurations
    # @option cascade_config [ActiveSupport::Duration] :delay Required. Time to wait before this step
    # @option cascade_config [Symbol, String] :target Required. Name of the optional target (e.g., :slack, :email)
    # @option cascade_config [Hash] :options Optional. Parameters to pass to the optional target
    # @param [Hash] options Additional options for cascade
    # @option options [Boolean] :validate (true) Whether to validate the cascade configuration
    # @option options [Boolean] :trigger_first_immediately (false) Whether to trigger the first target immediately without delay
    # @return [Boolean] true if cascade was initiated successfully, false otherwise
    # @raise [ArgumentError] if cascade_config is invalid and :validate is true
    def cascade_notify(cascade_config, options = {})
      validate = options.fetch(:validate, true)
      trigger_first_immediately = options.fetch(:trigger_first_immediately, false)
      
      # Validate configuration if requested
      if validate
        validation_result = validate_cascade_config(cascade_config)
        unless validation_result[:valid]
          raise ArgumentError, "Invalid cascade configuration: #{validation_result[:errors].join(', ')}"
        end
      end
      
      # Return false if cascade config is empty
      return false if cascade_config.blank?
      
      # Return false if notification is already opened
      return false if opened?
      
      if defined?(ActiveJob) && defined?(ActivityNotification::CascadingNotificationJob) && 
         ActivityNotification::CascadingNotificationJob.respond_to?(:perform_later)
        if trigger_first_immediately && cascade_config.any?
          # Trigger first target immediately
          first_step = cascade_config.first
          target_name = first_step[:target] || first_step['target']
          target_options = first_step[:options] || first_step['options'] || {}
          
          # Perform the first step synchronously
          perform_cascade_step(target_name, target_options)
          
          # Schedule remaining steps if any
          if cascade_config.length > 1
            remaining_config = cascade_config[1..-1]
            first_delay = remaining_config.first[:delay] || remaining_config.first['delay']
            
            if first_delay.present?
              ActivityNotification::CascadingNotificationJob
                .set(wait: first_delay)
                .perform_later(id, remaining_config, 0)
            end
          end
        else
          # Schedule first step with its configured delay
          first_step = cascade_config.first
          first_delay = first_step[:delay] || first_step['delay']
          
          if first_delay.present?
            ActivityNotification::CascadingNotificationJob
              .set(wait: first_delay)
              .perform_later(id, cascade_config, 0)
          else
            # If no delay specified for first step, trigger immediately
            ActivityNotification::CascadingNotificationJob
              .perform_later(id, cascade_config, 0)
          end
        end
        
        true
      else
        Rails.logger.error("ActiveJob or CascadingNotificationJob not available for cascading notifications")
        false
      end
    end
    
    # Validates a cascade configuration array
    #
    # @param [Array<Hash>] cascade_config The configuration to validate
    # @return [Hash] Hash with :valid (Boolean) and :errors (Array<String>) keys
    def validate_cascade_config(cascade_config)
      errors = []
      
      if cascade_config.nil?
        errors << "cascade_config cannot be nil"
        return { valid: false, errors: errors }
      end
      
      unless cascade_config.is_a?(Array)
        errors << "cascade_config must be an Array"
        return { valid: false, errors: errors }
      end
      
      if cascade_config.empty?
        errors << "cascade_config cannot be empty"
      end
      
      cascade_config.each_with_index do |step, index|
        unless step.is_a?(Hash)
          errors << "Step #{index} must be a Hash"
          next
        end
        
        # Check for required target parameter
        target = step[:target] || step['target']
        if target.nil?
          errors << "Step #{index} missing required :target parameter"
        elsif !target.is_a?(Symbol) && !target.is_a?(String)
          errors << "Step #{index} :target must be a Symbol or String"
        end
        
        # Check for delay parameter (only required for steps after the first if not using trigger_first_immediately)
        delay = step[:delay] || step['delay']
        if delay.nil?
          errors << "Step #{index} missing :delay parameter"
        elsif !delay.respond_to?(:from_now) && !delay.is_a?(Numeric)
          errors << "Step #{index} :delay must be an ActiveSupport::Duration or Numeric (seconds)"
        end
        
        # Check options if present
        options = step[:options] || step['options']
        if options.present? && !options.is_a?(Hash)
          errors << "Step #{index} :options must be a Hash"
        end
      end
      
      { valid: errors.empty?, errors: errors }
    end
    
    # Checks if a cascading notification is currently in progress for this notification
    # This is a helper method that checks if there are scheduled jobs for this notification
    #
    # @return [Boolean] true if cascade jobs are scheduled (this is a best-effort check)
    def cascade_in_progress?
      # This is a best-effort check that returns false by default
      # In production, you might want to track this state differently
      # (e.g., in Redis, database flag, or by querying the job queue)
      false
    end
    
    private
    
    # Performs a single cascade step immediately (synchronously)
    # @api private
    # @param [Symbol, String] target_name Name of the optional target
    # @param [Hash] options Options to pass to the optional target
    # @return [Hash] Result of the operation
    def perform_cascade_step(target_name, options = {})
      target_name_sym = target_name.to_sym
      
      # Get all configured optional targets for this notification
      optional_targets = notifiable.optional_targets(
        target.to_resources_name,
        key
      )
      
      # Find the matching optional target
      optional_target = optional_targets.find do |ot|
        ot.to_optional_target_name == target_name_sym
      end
      
      if optional_target.nil?
        Rails.logger.warn("Optional target '#{target_name}' not found for notification #{id}")
        return { target_name_sym => :not_configured }
      end
      
      # Check subscription status
      unless optional_target_subscribed?(target_name_sym)
        Rails.logger.info("Target not subscribed to optional target '#{target_name}' for notification #{id}")
        return { target_name_sym => :not_subscribed }
      end
      
      # Trigger the optional target
      begin
        optional_target.notify(self, options)
        Rails.logger.info("Successfully triggered optional target '#{target_name}' for notification #{id}")
        { target_name_sym => :success }
      rescue => e
        Rails.logger.error("Failed to trigger optional target '#{target_name}' for notification #{id}: #{e.message}")
        if ActivityNotification.config.rescue_optional_target_errors
          { target_name_sym => e }
        else
          raise e
        end
      end
    end
  end
end
