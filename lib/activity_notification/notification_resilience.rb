module ActivityNotification
  # Provides resilient notification handling across different ORMs
  # Handles missing notification scenarios gracefully without raising exceptions
  module NotificationResilience
    extend ActiveSupport::Concern

    # Exception classes for different ORMs
    ORM_EXCEPTIONS = {
      active_record: 'ActiveRecord::RecordNotFound',
      mongoid: 'Mongoid::Errors::DocumentNotFound', 
      dynamoid: 'Dynamoid::Errors::RecordNotFound'
    }.freeze

    class_methods do
      # Returns the current ORM being used
      # @return [Symbol] The ORM symbol (:active_record, :mongoid, :dynamoid)
      def current_orm
        ActivityNotification.config.orm
      end

      # Returns the exception class for the current ORM
      # @return [Class] The exception class for missing records in current ORM
      def record_not_found_exception_class
        exception_name = ORM_EXCEPTIONS[current_orm]
        return nil unless exception_name
        
        begin
          exception_name.constantize
        rescue NameError
          nil
        end
      end

      # Checks if an exception is a "record not found" exception for any supported ORM
      # @param [Exception] exception The exception to check
      # @return [Boolean] True if the exception indicates a missing record
      def record_not_found_exception?(exception)
        ORM_EXCEPTIONS.values.any? do |exception_name|
          begin
            exception.is_a?(exception_name.constantize)
          rescue NameError
            false
          end
        end
      end
    end

    # Module-level methods that delegate to class methods
    def self.current_orm
      ActivityNotification.config.orm
    end

    def self.record_not_found_exception_class
      exception_name = ORM_EXCEPTIONS[current_orm]
      return nil unless exception_name
      
      begin
        exception_name.constantize
      rescue NameError
        nil
      end
    end

    def self.record_not_found_exception?(exception)
      ORM_EXCEPTIONS.values.any? do |exception_name|
        begin
          exception.is_a?(exception_name.constantize)
        rescue NameError
          false
        end
      end
    end

    # Executes a block with resilient notification handling
    # Catches ORM-specific "record not found" exceptions and logs them appropriately
    # @param [String, Integer] notification_id The ID of the notification being processed
    # @param [Hash] context Additional context for logging
    # @yield Block to execute with resilient handling
    # @return [Object, nil] Result of the block, or nil if notification was not found
    def with_notification_resilience(notification_id = nil, context = {})
      yield
    rescue => exception
      if self.class.record_not_found_exception?(exception)
        log_missing_notification(notification_id, exception, context)
        nil
      else
        raise exception
      end
    end

    private

    # Logs a warning when a notification is not found
    # @param [String, Integer] notification_id The ID of the missing notification
    # @param [Exception] exception The exception that was caught
    # @param [Hash] context Additional context for logging
    def log_missing_notification(notification_id, exception, context = {})
      orm_name = self.class.current_orm
      exception_class = exception.class.name
      
      message = "ActivityNotification: Notification"
      message += " with id #{notification_id}" if notification_id
      message += " not found for email delivery"
      message += " (#{orm_name}/#{exception_class})"
      message += ", likely destroyed before job execution"
      
      if context.any?
        context_info = context.map { |k, v| "#{k}: #{v}" }.join(', ')
        message += " [#{context_info}]"
      end

      Rails.logger.warn(message)
    end
  end
end