if defined?(ActiveJob)
  class ActivityNotification::NotifyToJob < ActivityNotification.config.parent_job.constantize
    queue_as ActivityNotification.config.active_job_queue
  
    def perform(target, notifiable, options = {})
      ActivityNotification::Notification.notify_to(target, notifiable, options)
    end
  end
end
