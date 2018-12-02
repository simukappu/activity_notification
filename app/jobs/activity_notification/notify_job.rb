if defined?(ActiveJob)
  class ActivityNotification::NotifyJob < ActivityNotification.config.parent_job.constantize
    queue_as ActivityNotification.config.active_job_queue
  
    def perform(target_type, notifiable, options = {})
      ActivityNotification::Notification.notify(target_type, notifiable, options)
    end
  end
end
