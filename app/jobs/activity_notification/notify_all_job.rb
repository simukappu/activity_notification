if defined?(ActiveJob)
  class ActivityNotification::NotifyAllJob < ActivityNotification.config.parent_job.constantize
    queue_as ActivityNotification.config.active_job_queue
  
    def perform(targets, notifiable, options = {})
      ActivityNotification::Notification.notify_all(targets, notifiable, options)
    end
  end
end
